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
        # IO.inspect("Received an requst from flink. #{inspect(raw_body)} ")
        toFn = Io.Statefun.Sdk.Reqreply.ToFunction.decode(raw_body).request
        {:invocation, protoInvocationRequest} = toFn

        protoFuncAddr = protoInvocationRequest.target

        funcAddress = translate_protobuf_to_sdk_func_addr(protoFuncAddr)
        target_function_spec = get_function_spec(state, funcAddress)

        stateReceivedFromFlink = StateFun.Address.AddressedScopedStorage.indexReceivedStateFromFlink(protoInvocationRequest.state)

        applyBatch(protoInvocationRequest.invocations, %{},  target_function_spec.function_callback)

        # TODO aggregate results
        
        {:reply, 200, state}
    end

    def g() do
        addr = StateFun.Address.init("a", "t", "d")
        IO.inspect(addr.func_type)
    end

    defp applyBatch(pbInvocationRequest, context, func_cb) do
        pbInvocationRequest 
        |> Enum.map(fn invocation -> process_invocation_request(invocation, func_cb) end)
        
    end

    # 
    defp process_invocation_request(invocation, func) do
        arg = invocation.argument
        message = StateFun.Message.init(arg.typename, arg.value)
        context = %{} # TODO logic adding context
        func.(context, message)
    end
    
    # TODO error handling if function spec
    defp get_function_spec(state, funcAddress) do 
        IO.inspect("State #{inspect(state)}, func_type: #{inspect(funcAddress.func_type)}")
        state[funcAddress.func_type]
    end

    # Translate the protobuf into an SDK representation of the function address object
    defp translate_protobuf_to_sdk_func_addr(address) do
        func_namespace = address.namespace
        func_type = address.type
        func_id  = address.id
        IO.inspect("Received function #{func_namespace}, type: #{func_type}, id: #{func_id}")
        StateFun.Address.init(func_namespace, func_type, func_id)
    end

    # TODO Error handling
    defp assert_protobuf_req_not_null(invocation_request) do
    end


    # TODO refactor these into seperate files
    defmodule Message do
        defstruct [:typename, :payload]
        def init(typename, payload) do 
            %Message{typename: typename, payload: payload}
        end
    end
    defmodule Address.AddressedScopedStorage do
        # Shouold be an list

        # TODO handle state updates
        def indexReceivedStateFromFlink(protoState) do
            IO.inspect("Received state from #{inspect(protoState)}")
            []
        end
    end

    defmodule Address do 
        defstruct [:func_namespace, :func_type, :func_id]
        def init(func_namespace, func_type, func_id) do
            %Address{func_namespace: func_namespace, func_type: func_type, func_id: func_id}
        end
    end

    defmodule FunctionSpecs do
        defstruct [:type_name, :function_callback, :state_value_specs]
    end 

    defmodule ValueSpecs do
        defstruct [:name, :type]
    end

end