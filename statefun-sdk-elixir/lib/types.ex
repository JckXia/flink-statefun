# -> In short, the SDK passes state/envelope value as TypeValue<T> wrapped in various other datastructure (Message<T>, ValueSpec<T>)etc
# -> it checks for type using
#     -> Type<T>.typename() against TypeValue<T>.typename
# -> decodes for select type by doing the following
#     -> get the raw value from TypeValue<T>
#     -> get the deserializer from Type<T>
#     -> decode into expected format using the deserializer()

## 

defmodule StateFun.TypeSerializer do
    @callback serialize(object :: any()) :: any()
    @callback deserialize(object :: any()) :: any()
end

defmodule StateFun.Type do
    @callback type_name(type :: any()) :: String.t()
    @callback type_serializer(type :: any()) :: StateFun.TypeSerializer.t()
end

defmodule StateFun.IntTypeSerializer do
    @behaviour StateFun.TypeSerializer
    def serialize(int_value) do
        int_wrapper = %Io.Statefun.Sdk.Types.IntWrapper{value: int_value}
        Io.Statefun.Sdk.Types.IntWrapper.encode(int_wrapper)
    end

    def deserialize(raw_binary) do
        Io.Statefun.Sdk.Types.IntWrapper.decode(raw_binary).value
    end
end


defmodule StateFun.BoolTypeSerializer do
    @behaviour StateFun.TypeSerializer
    def serialize(bool_value) do
        bool_wrapper = %Io.Statefun.Sdk.Types.BooleanWrapper{value: bool_value}
        Io.Statefun.Sdk.Types.BooleanWrapper.encode(bool_wrapper)
    end

    def deserialize(raw_binary) do
        Io.Statefun.Sdk.Types.BooleanWrapper.decode(raw_binary).value
    end
end

defmodule StateFun.BooleanType do
    @behaviour StateFun.Type
    def type_name() do
        "io.statefun.types/boolean"
    end

    def type_serializer() do
        StateFun.BoolTypeSerializer
    end
end

defmodule StateFun.IntType do
    @behaviour StateFun.Type
    def type_name() do
        "io.statefun.types/int"
    end

    def type_serializer() do
        StateFun.IntTypeSerializer
    end
end


defmodule Types do
    @bOOLEAN_TYPENAME "io.statefun.types/bool"
end