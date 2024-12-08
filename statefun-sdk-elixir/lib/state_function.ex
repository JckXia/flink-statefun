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
            type_typename: state_value_spec.type.type_name}
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

    # TODO make state_value_specs a list, not just an attribute
    defmodule FunctionSpecs do
        defstruct [:type_name, :function_callback, :state_value_specs]
    end 

    defmodule ValueSpecs do
        defstruct [:name, :type]
    end
end