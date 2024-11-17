defmodule StateFun do  
    use GenServer


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

    defmodule Message do
        defstruct [targetAddress: nil, payload: nil, typedValue: nil]
        
        # Method to parse message into an int
        def as_int(message) do
            packet = message.typedValue.value
            Io.Statefun.Sdk.Types.IntWrapper.decode(packet).value
        end

        def typed_val_as_int(typedVal) do 
            Io.Statefun.Sdk.Types.IntWrapper.decode(typedVal).value
        end

        # Method to check whether message is an int
        def is_int(message) do 
            message.typedValue.typename == :sfixed32 or message.typedValue.typename == "sfixed32"  
        end

        def build_int(value) do
            basic_int = %Io.Statefun.Sdk.Types.IntWrapper{value: value}
            wrapper = Io.Statefun.Sdk.Types.IntWrapper.encode(basic_int)
            %Io.Statefun.Sdk.Reqreply.TypedValue{typename: "sfixed32", has_value: true, value: wrapper}
        end

        # TODO, reconcile these two. Type is a bit messsed up at the moment 
        def build_int_state(value) do
            basic_int = %Io.Statefun.Sdk.Types.IntWrapper{value: value}
            wrapper = Io.Statefun.Sdk.Types.IntWrapper.encode(basic_int)
            %Io.Statefun.Sdk.Reqreply.TypedValue{typename: "io.statefun.types/int", has_value: true, value: wrapper}
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
        
        storage = StateFun.Address.AddressedScopedStorage.extractKnownStateFromSpec(funcAddress, state, stateReceivedFromFlink)

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
    #   -> For each item in storage, if :MODIFIED
    #       -> create PersistedValueMutation object
    #           -> state_name: string
    #           -> state_value: cell.state_value
    defp aggregate_state_mutations(invocationResponse, storage) do  
        mutation_list = Enum.filter(storage, fn {_state_name, state_cell} -> state_cell.state_status == :MODIFIED end)  
                    |> Enum.map(fn {state_name, state_cell} ->  
                                    %Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueMutation{mutation_type: :MODIFY, state_name: to_string(state_name), state_value: state_cell.state_value}
                    end)
        
        # IO.inspect("[SDK] Mutation modification list after invocation #{inspect(mutation_list)}")
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

     def indexReceivedStateFromFlink(stateFunStates) do
            IO.inspect("[SDK] Received state from #{inspect(stateFunStates)}")
                    
            stateFunStates
            |> Enum.map(fn state -> {state.state_name, state.state_value} end)
            |> Enum.into(%{})
    end

    # stateReceived is a flipping map, because we formatted it using 134 
    def find_missing_value_specs(functionSpec, stateReceivedFromFlink) do 
        missing = Enum.filter(functionSpec, fn {_spec, func_spec} -> func_spec.state_value_specs != nil end) 
                |>  Enum.reduce(%{}, fn {func_name, func_spec}, acc -> 
                        state_value_spec = func_spec.state_value_specs
                        if value_spec_found?(state_value_spec.name, stateReceivedFromFlink) == false do
                            Map.put(acc, state_value_spec.name, state_value_spec)
                        end 
                end)
        missing
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
        message = %StateFun.Message{targetAddress: nil, payload: arg.value, typedValue: arg}
        ctx = func.(context, message)
        process_invoc_request(tail, ctx, func)
    end
    
    # TODO error handling (a bunch of different places really)
    defp get_function_spec(state, funcAddress) do 
        # IO.inspect("State #{inspect(state)}, func_type: #{inspect(funcAddress.func_type)}")
        state[funcAddress.func_type]
    end

    # Translate the protobuf into an SDK representation of the function address object
    defp translate_protobuf_to_sdk_func_addr(address) do
        func_namespace = address.namespace
        func_type = address.type
        func_id  = address.id
        # IO.inspect("Received function #{func_namespace}, type: #{func_type}, id: #{func_id}")
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
 
     # An 3-uple object, tracks state information
    #   -> on set, status mutates to MODIFIED
    #   -> on remove, status mutates to DELETED
    #   (Needed by Flink/StateFun runtime to know what to do with state)
    defmodule Address.AddressedScopedStorage.Cell do 
        defstruct [state_type: nil, state_value: nil, state_status: :UNMODIFIED]
        def init(state_type) do
            %Address.AddressedScopedStorage.Cell{state_type: state_type}
        end

        def set(cell, new_val) do
            %Address.AddressedScopedStorage.Cell{ cell | state_value: new_val, state_status: :MODIFIED}
        end

        def get(cell) do
            cell.state_value
        end

        def delete(cell) do
            %Address.AddressedScopedStorage.Cell{ cell | state_value: nil, state_status: :DELETED}
        end
    end
    
    defmodule Address.AddressedScopedStorage do

        # [Io.Statefun.Sdk.Reqreply.ToFunction.PersistedValue]
        def indexReceivedStateFromFlink(stateFunStates) do
            IO.inspect("[SDK] Received state from #{inspect(stateFunStates)}")
                    
            stateFunStates
            |> Enum.map(fn state -> {state.state_name, state.state_value} end)
            |> Enum.into(%{})
        end

        def find_missing_value_specs(functionSpec, stateReceivedFromFlink) do 
            
            missing = Enum.filter(functionSpec, fn {_spec, func_spec} -> func_spec.state_value_specs != nil end) 
                    |>  Enum.reduce(%{}, fn {func_name, func_spec}, acc -> 
                            state_value_spec = func_spec.state_value_specs
                            if stateReceivedFromFlink[state_value_spec.name] == nil do
                                Map.put(acc, state_value_spec.name, state_value_spec)
                            end  

                        end)     
            IO.inspect("We are missing valueSpecs ack from Flink #{inspect(missing)}")
            missing
        end
        
        # TODO error handling + refactor, but assume happy path for now
        def extractKnownStateFromSpec(funcAddress, functionSpec, stateReceivedFromFlink) do
            storage_object = %{}
            
            # Generate a list of value specs that user have defined, but flink does not know about
            #  -> When this happens, need to 
            #Init storage object with known state spec name
            storage_object = Enum.reduce(functionSpec, %{}, fn {func_name, func_spec}, acc -> 
                if func_spec.state_value_specs != nil and funcAddress.func_type == func_spec.type_name do
                    cell = %Address.AddressedScopedStorage.Cell{state_type: func_spec.state_value_specs.type}
                    # IO.inspect("State recv from flink #{inspect(stateReceivedFromFlink)}")
                    if stateReceivedFromFlink[func_spec.state_value_specs.name] != nil do
                      found_flink_state_typed_value = stateReceivedFromFlink[func_spec.state_value_specs.name]
                      cell = %Address.AddressedScopedStorage.Cell{cell | state_type: found_flink_state_typed_value.typename,   state_value: found_flink_state_typed_value.value}
                      Map.put(acc, func_spec.state_value_specs.name, cell)
                    else 
                      Map.put(acc, func_spec.state_value_specs.name, cell)
                    end
                else 
                    acc
                end
            end)

            storage_object
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