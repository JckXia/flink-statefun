defmodule StateFun.Context  do
    alias StateFun
    alias StateFun.Message
    defstruct [:storage, :self, :internalContext]

    defmodule InternalContext do 
        defstruct [caller: nil, sent: [], egress: [], delayed: []]
    end 
 
    # Self is the Address of current function
    def init(self, storage) do
        %__MODULE__{storage: storage, self: self, internalContext: %InternalContext{}}
    end

    def send(context, %StateFun.Message{} = msg) do        
        updatedSent = [msg] ++ context.internalContext.sent
        internalContext = %InternalContext{context.internalContext | sent: updatedSent}

        %__MODULE__{context | internalContext: internalContext}
    end

    def send(context, %StateFun.EgressMessage{} = msg) do 
        IO.inspect("Dispatch egress messages!")
        context
    end 

    # TODO once we are confident simple send works
    def sendAfter(delay, message, cancellationToken) do end
    def cancelDelayedMessage(cancellationToken) do end
end