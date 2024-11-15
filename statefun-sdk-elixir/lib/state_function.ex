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

        # Method to check whether message is an int
        def is_int(message) do 
            message.typedValue.typename == :sfixed32 or message.typedValue.typename == "sfixed32"  
        end

        def build_int(value) do
            basic_int = %Io.Statefun.Sdk.Types.IntWrapper{value: value}
            wrapper = Io.Statefun.Sdk.Types.IntWrapper.encode(basic_int)
            %Io.Statefun.Sdk.Reqreply.TypedValue{typename: :sfixed32, has_value: true, value: wrapper}
        end
    end


    @impl True
    def handle_call({:async_invoke, raw_body}, _from, state) do 
        IO.inspect("[SDK] Received request from flink!")
        toFn = Io.Statefun.Sdk.Reqreply.ToFunction.decode(raw_body).request
        {:invocation, protoInvocationRequest} = toFn

        protoFuncAddr = protoInvocationRequest.target

        funcAddress = translate_protobuf_to_sdk_func_addr(protoFuncAddr)
        target_function_spec = get_function_spec(state, funcAddress)

        stateReceivedFromFlink = StateFun.Address.AddressedScopedStorage.indexReceivedStateFromFlink(protoInvocationRequest.state)

        contextObject = StateFun.Context.init(funcAddress)
        updatedContextObject =  applyBatch(protoInvocationRequest.invocations, contextObject, target_function_spec.function_callback)
        
        # TODO aggregate results
        invocationResponse = %Io.Statefun.Sdk.Reqreply.FromFunction.InvocationResponse{}
        invocationResponse = aggregate_sent_messages(invocationResponse, updatedContextObject.internalContext.sent)

        fromFunc = %Io.Statefun.Sdk.Reqreply.FromFunction{response: {:invocation_result, invocationResponse}}
        binary_resp = Io.Statefun.Sdk.Reqreply.FromFunction.encode(fromFunc)
        {:reply, binary_resp, state}
    end

    def g() do
        addr = StateFun.Address.init("a", "t", "d")
        IO.inspect(addr.func_type)
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
        def init(self) do
            %Context{storage: %{}, self: self, internalContext: %InternalContext{}}
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
 
  
    defmodule Address.AddressedScopedStorage do
        # Shouold be an list
        # TODO handle state updates
        def indexReceivedStateFromFlink(protoState) do
            IO.inspect("[SDK] Received state from #{inspect(protoState)}")
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