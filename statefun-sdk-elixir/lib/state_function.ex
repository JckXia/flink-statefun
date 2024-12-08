defmodule StateFun do  
    use GenServer

    @state_fun_int_type "io.statefun.types/int"

    @impl true
    def init(function_specs) do
        init_state  =
            function_specs
            |> Enum.map(&bind/1)
            |> Map.new
        {:ok, init_state}
    end

    def bind(function_spec) do
        {function_spec.type_name, function_spec}
    end

    def get_int_type() do
      @state_fun_int_type
    end

    # TODO: This abstraction is incorrect. Fix this
    defmodule TypedValue do 
        defstruct [typedname: nil, has_value: false, value: nil]
        
        def is_int(typedvalue) do 
            typedvalue.typename == StateFun.get_int_type()
        end

        def as_int(typedvalue) do
            Io.Statefun.Sdk.Types.IntWrapper.decode(typedvalue.value).value
        end

        def from_int(int_val) do
            basic_int = %Io.Statefun.Sdk.Types.IntWrapper{value: int_val}
            wrapper = Io.Statefun.Sdk.Types.IntWrapper.encode(basic_int)
            %Io.Statefun.Sdk.Reqreply.TypedValue{typename: StateFun.get_int_type(), has_value: true, value: wrapper}
        end
    end

    @impl True
    def handle_call({:async_invoke, raw_body}, _from, state) do 
        toFn = Io.Statefun.Sdk.Reqreply.ToFunction.decode(raw_body).request
        {:invocation, protoInvocationRequest} = toFn

        stateReceivedFromFlink = StateFun.indexReceivedStateFromFlink(protoInvocationRequest.state)
        missing_value_specs = StateFun.find_missing_value_specs(state, stateReceivedFromFlink)
        binary_resp = process_invocation_request(missing_value_specs, protoInvocationRequest, state, stateReceivedFromFlink)
        {:reply, binary_resp, state}
    end
    
    defp process_invocation_request(missing_value_specs, protoInvocationRequest, state, stateReceivedFromFlink) when map_size(missing_value_specs) != 0 do 
        IO.inspect("[SDK] Some stateValue specs are missing #{inspect(missing_value_specs)}")
        
        missing_values = missing_value_specs 
            |> Enum.map(fn {state_name, state_value_spec} -> 
            %Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueSpec{state_name: state_name, 
            expiration_spec: nil,
            type_typename: state_value_spec.type}
        end)

        invocationResponse = %Io.Statefun.Sdk.Reqreply.FromFunction.IncompleteInvocationContext{missing_values: missing_values}

        fromFunc = %Io.Statefun.Sdk.Reqreply.FromFunction{response: {:incomplete_invocation_context, invocationResponse}}
        Io.Statefun.Sdk.Reqreply.FromFunction.encode(fromFunc)
    end

    defp process_invocation_request(missing_value_specs, protoInvocationRequest, state, stateReceivedFromFlink) do 
        protoFuncAddr = protoInvocationRequest.target

        funcAddress = translate_protobuf_to_sdk_func_addr(protoFuncAddr)
        target_function_spec = get_function_spec(state, funcAddress)
        
        storage = StateFun.Address.AddressedScopedStorage.convertFlinkStateIntoFunctionScopedStorage(funcAddress, state, stateReceivedFromFlink)
        contextObject = StateFun.Context.init(funcAddress, storage)
        updatedContextObject =  applyBatch(protoInvocationRequest.invocations, contextObject, target_function_spec.function_callback)

        invocationResponse = %Io.Statefun.Sdk.Reqreply.FromFunction.InvocationResponse{}

        invocationResponse = invocationResponse 
                            |> aggregate_sent_messages(updatedContextObject.internalContext.sent)
                            |> aggregate_state_mutations(updatedContextObject.storage)

        fromFunc = %Io.Statefun.Sdk.Reqreply.FromFunction{response: {:invocation_result, invocationResponse}}
        Io.Statefun.Sdk.Reqreply.FromFunction.encode(fromFunc)
    end

    # Pseudo-code:
    #   -> For each item in storage, if :MODIFIED/:DELETED
    #       -> create PersistedValueMutation object
    #           -> state_name: string
    #           -> state_value: cell.state_value
    defp aggregate_state_mutations(invocationResponse, storage) do 
        mutation_list = Enum.filter(storage.cells, fn {_state_name, state_cell} -> (state_cell.state_status == :MODIFY or state_cell.state_status == :DELETE) end)  
                    |> Enum.map(fn {state_name, state_cell} ->  
                                    %Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueMutation{mutation_type: state_cell.state_status, state_name: to_string(state_name), state_value: state_cell.state_value}
                    end)
        
        %Io.Statefun.Sdk.Reqreply.FromFunction.InvocationResponse{invocationResponse | state_mutations: mutation_list}
    end

    # Function to Function messages
    defp aggregate_sent_messages(invocationResponse, sentMessages) do 
        outGoingMsg = sentMessages
        |> Enum.map(fn msg -> sent_msg_to_pb(msg) end)
        invocationResponse =%Io.Statefun.Sdk.Reqreply.FromFunction.InvocationResponse{ invocationResponse | outgoing_messages: outGoingMsg }
        invocationResponse
    end

    defp sent_msg_to_pb(sentMsg) do
        sdkAddr = sentMsg.targetAddress
        pbAddr = translate_sdk_func_addr_to_pb_addr(sdkAddr)

        pbArg = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: to_string(sentMsg.typedValue.typename) , has_value: true, value: sentMsg.typedValue.value }
        %Io.Statefun.Sdk.Reqreply.FromFunction.Invocation{target: pbAddr, argument: pbArg}
    end

    # PersistedValue is what Flink gives
     def indexReceivedStateFromFlink(stateFunStates) do
            stateFunStates
            |> Enum.map(fn state -> {state.state_name, state.state_value} end)
            |> Enum.into(%{})
    end

    # stateReceived is a flipping map, because we formatted it using 134 
    def find_missing_value_specs(functionSpec, stateReceivedFromFlink) do 
        missing = Enum.filter(functionSpec, fn {_spec, func_spec} -> func_spec.state_value_specs != nil end) 
                |>  Enum.reduce(%{}, fn {func_name, func_spec}, acc -> 
                        state_value_spec_list = func_spec.state_value_specs
                        collect_missing_value_specs(state_value_spec_list, stateReceivedFromFlink, acc)
                end)
        missing
    end

    defp collect_missing_value_specs([] = _state_spec_list, _stateReceivedFromFlink, acc) do
        acc 
    end

    defp collect_missing_value_specs([state_value_spec | tail] = _state_spec_list, stateReceivedFromFlink, acc) do
        if value_spec_found?(state_value_spec.name, stateReceivedFromFlink) == false do
           acc = Map.put(acc, state_value_spec.name, state_value_spec)
           collect_missing_value_specs(tail, stateReceivedFromFlink, acc)
        else
            acc
        end
    end

    defp value_spec_found?(state_name, stateMap) when map_size(stateMap) == 0  do 
        false
    end

    defp value_spec_found?(state_name, stateReceivedFromFlink) do 
        Map.has_key?(stateReceivedFromFlink, state_name)
    end

    defp applyBatch(pbInvocationRequest, context, func_cb) do
        process_invoc_request(pbInvocationRequest, context, func_cb)
    end

    defp process_invoc_request([] = _invoc, context, func) do 
        context
    end

    defp process_invoc_request([invocation | tail] = _invoc, context, func) do
        arg = invocation.argument
        message = %StateFun.Message{targetAddress: nil, typedValue: arg}
        ctx = func.(context, message)
        process_invoc_request(tail, ctx, func)
    end
    
    # TODO error handling (a bunch of different places really)
    defp get_function_spec(state, funcAddress) do 
        state[funcAddress.func_type]
    end

    # Translate the protobuf into an SDK representation of the function address object
    defp translate_protobuf_to_sdk_func_addr(address) do
        func_namespace = address.namespace
        func_type = address.type
        func_id  = address.id
  
        StateFun.Address.init(func_namespace, func_type, func_id)
    end

    defp translate_sdk_func_addr_to_pb_addr(address) do
       name_space = address.func_namespace
       func_type = address.func_type
       func_id = address.func_id
       %Io.Statefun.Sdk.Reqreply.Address{namespace: name_space, type: func_type, id: func_id}
    end

    # TODO Error handling
    defp assert_protobuf_req_not_null(invocation_request) do
    end

    # TODO refactor these into seperate files
    defmodule EgressMessage do 
        defstruct [:typename, :payload]
         def init(typename, payload) do 
            %EgressMessage{typename: typename, payload: payload}
        end
    end

    defmodule Context  do
        alias StateFun
        alias StateFun.Message
        defstruct [:storage, :self, :internalContext]

        defmodule InternalContext do 
            defstruct [caller: nil, sent: [], egress: [], delayed: []]
        end 
     
        # Self is the Address of current function
        def init(self, storage) do
            %Context{storage: storage, self: self, internalContext: %InternalContext{}}
        end

        def send(context, %StateFun.Message{} = msg) do        
            updatedSent = [msg] ++ context.internalContext.sent
            internalContext = %InternalContext{context.internalContext | sent: updatedSent}
    
            %Context{context | internalContext: internalContext}
        end

        def send(context, %StateFun.EgressMessage{} = msg) do 
            IO.inspect("Dispatch egress messages!")
            context
        end 


        # TODO once we are confident simple send works
        def sendAfter(delay, message, cancellationToken) do end
        def cancelDelayedMessage(cancellationToken) do end
    end
 
     # An internal, 3-uple object, tracks state information
    #   -> on set, status mutates to MODIFIY
    #   -> on remove, status mutates to DELETE
    defmodule Address.AddressedScopedStorage.Cell do 
        defstruct [state_value: nil, state_status: :UNMODIFIED]

        def get_internal(cell) do
            deserialized_val = try_decode_typed_value(cell.state_value)
            extract_deserialized_value(deserialized_val)
        end

        def set_internal(cell, valueSpec, value) do
            new_typed_val = serialize(valueSpec.type, value)
            %Address.AddressedScopedStorage.Cell{ cell | state_value: new_typed_val, state_status: :MODIFY}
        end

        def delete_internal(cell) do
            %Address.AddressedScopedStorage.Cell{ cell | state_value: nil, state_status: :DELETE}
        end

        defp serialize(typename, value) when typename == "io.statefun.types/int" do
           StateFun.TypedValue.from_int(value)
        end

        # TODO figure out best way to manage types. (Supply an s/derializer map?)
        defp try_decode_typed_value(state_value) when state_value.typename == "io.statefun.types/int" do 
            Io.Statefun.Sdk.Types.IntWrapper.decode(state_value.value)
        end

        defp try_decode_typed_value(state_value) when state_value == nil do
            nil
        end

        defp extract_deserialized_value(nil) do
            nil 
        end
        
        defp extract_deserialized_value(state_value) do
            state_value.value
        end
    end
    
    defmodule Address.AddressedScopedStorage do
        # Todo: Cell is a map, but can easily be an list
        defstruct [:cells]
        
        # Assume valueSpec.name is found
        def get(storage, valueSpec) do
            get_target_cell(storage, valueSpec)
            |> Address.AddressedScopedStorage.Cell.get_internal()
        end
        
        # ValueSpec<T>, T
        def set(storage, valueSpec, value) do           
            new_cell = get_target_cell(storage, valueSpec)
                        |> Address.AddressedScopedStorage.Cell.set_internal(valueSpec, value)
                    
            updated_cells = Map.put(storage.cells, valueSpec.name, new_cell)
            %{storage | cells: updated_cells }    
        end

        def remove(storage, valueSpec) do
            deleted_cell = get_target_cell(storage, valueSpec)
                            |> Address.AddressedScopedStorage.Cell.delete_internal()
            updated_cells = Map.put(storage.cells, valueSpec.name, deleted_cell)
            %{storage | cells: updated_cells }
        end
        
        # TODO, err handling?
        defp get_target_cell(storage, valueSpec) do
            storage.cells[valueSpec.name]
        end

        # Semantic: Using the functionSpec pointed to by funcAddress (as a template), construct an object
        #   containing the valueSpec name mapped to actual state sent by Flink
        def convertFlinkStateIntoFunctionScopedStorage(funcAddress, functionSpec, stateReceivedFromFlink) do
            functionSpec[funcAddress.func_type]
            |> generate_cells_from_function_spec(stateReceivedFromFlink)
        end

        defp generate_cells_from_function_spec(target_function_spec, stateReceivedFromFlink) when length(target_function_spec.state_value_specs) == 0 do
            %__MODULE__{cells: %{}}
        end
        
        defp generate_cells_from_function_spec(target_function_spec, stateReceivedFromFlink) do
            state_spec_lst = target_function_spec.state_value_specs
            
            cells = generate_cells_from_value_spec_list(state_spec_lst, stateReceivedFromFlink, %{})
            %__MODULE__{cells: cells}
        end
    
        defp generate_cells_from_value_spec_list([], _stateReceivedFromFlink, cells) do
            cells
        end
        
        defp generate_cells_from_value_spec_list([state_value_spec | tail] = _state_spec_list, stateReceivedFromFlink, cells) do
            state_name = state_value_spec.name
            state_val_supplied_by_flink = stateReceivedFromFlink[state_name]
            new_cell = %Address.AddressedScopedStorage.Cell{state_value: state_val_supplied_by_flink}
            cells = Map.put(cells, state_name, new_cell)
            generate_cells_from_value_spec_list(tail, stateReceivedFromFlink, cells)
        end

    end

 

    defmodule Address do 
        defstruct [:func_namespace, :func_type, :func_id]
        def init(func_namespace, func_type, func_id) do
            %Address{func_namespace: func_namespace, func_type: func_type, func_id: func_id}
        end
    end

    # TODO make state_value_specs a list, not just an attribute
    defmodule FunctionSpecs do
        defstruct [:type_name, :function_callback, :state_value_specs]
    end 

    defmodule ValueSpecs do
        defstruct [:name, :type]
    end

end