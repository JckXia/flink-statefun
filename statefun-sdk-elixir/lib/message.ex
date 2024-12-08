defmodule StateFun.Message do
    defstruct [targetAddress: nil, typedValue: nil]
    ## TODO replacing the existing Message decoding with this
    def is_int(message) do
        is(message, StateFun.IntType)
    end
    
    def as_int(message) do
        as(message, StateFun.IntType)
    end

    def is(message, type) do
        message.typedValue.typename == type.type_name()
    end

    def as(message, type) do
        typed_value = message.typedValue
        type.type_serializer.deserialize(typed_value.value)
    end

    def build(targetAddr, value, type) do
        type_serializer = type.type_serializer
        serialized_value = type_serializer.serialize(value)

        typed_value = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: type.type_name, has_value: true, value: serialized_value}
        %__MODULE__{targetAddress: targetAddr, typedValue: typed_value}
    end
end