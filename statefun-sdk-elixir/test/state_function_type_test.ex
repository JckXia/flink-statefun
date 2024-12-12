defmodule StateFuncTypeTest do
    use ExUnit.Case
    alias StateFun
    
    @int_type_name "io.statefun.types/int"
    @bool_type_name "io.statefun.types/boolean"

    test "should serialize and deserialize primitive ints into protobufs" do
        int_val = 24
        assert StateFun.IntType.type_name == @int_type_name
        bin_value = StateFun.IntType.type_serializer.serialize(int_val)
        actual_val = StateFun.IntType.type_serializer.deserialize(bin_value)
        assert int_val == actual_val
    end
   
    test "should serialize and deserialize boolean into protobufs" do
        bool_val = true
        assert StateFun.BooleanType.type_name == @bool_type_name
        bin_value = StateFun.BooleanType.type_serializer.serialize(bool_val)
        actual_val = StateFun.BooleanType.type_serializer.deserialize(bin_value)
        assert actual_val == bool_val
    end
end