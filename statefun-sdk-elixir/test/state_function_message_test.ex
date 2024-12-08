defmodule StateFuncMessageTest do
    use ExUnit.Case
    alias StateFun
    
    @int_type_name "io.statefun.types/int"
    @bool_type_name "io.statefun.types/boolean"
    @custom_test_type_name "com.test.types/test_type"

    defmodule JsonSerializer do
        @behaviour StateFun.TypeSerializer
        def serialize(object) do
            {:ok, res} = JSON.encode(object)
            res
        end
    
        def deserialize(json_str) do
            {:ok, res} = JSON.decode(json_str)
            res  
        end
    end

    defmodule TestType do
        defstruct [name: nil, age: nil]

        @behaviour StateFun.Type
        def type_name() do
            @custom_test_type_name
        end

        def type_serializer() do
            JsonSerializer
        end
    end

    # TODO, confirm Message's typedValue is indeed an TypedValue object
    test "should decode message into int type successfully" do
        raw_value = StateFun.IntType.type_serializer.serialize(12)
        int_typed_value = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: @int_type_name, has_value: true, value: raw_value}
        
        int_message = %StateFun.Message{typedValue: int_typed_value}

        message_value = StateFun.Message.as_int(int_message)
        assert message_value == 12

        assert StateFun.Message.is_int(int_message) == true
    end

    test "should be able to build int messages" do
        message = StateFun.Message.build(nil, 12, StateFun.IntType)
        assert message.typedValue.has_value == true

        message_value = StateFun.Message.as_int(message)
        assert message_value == 12
    end
   
    test "should be able to build and decipher custom objects" do
        k = %TestType{name: "Jack", age: 25}
        message = StateFun.Message.build(nil, Map.from_struct(k), TestType)
        assert StateFun.Message.is(message, TestType) == true
        message_map = StateFun.Message.as(message, TestType)

        assert map_size(message_map) == 2
        assert message_map["name"] == "Jack"
        assert message_map["age"] == 25
    end

    test "should serialize and deserialize custom types" do

    end
end
