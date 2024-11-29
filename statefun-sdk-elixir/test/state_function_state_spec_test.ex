# Functions of interest
#   -> extractKnownStateFromSpec
#   -> find_missing_value_specs

# Brain storm:
#   -> Current Data-structure/relationships:
#       -> 1 FunctionSpec mapped to (at most) 1 state ValueSpec
#       -> find_missing_value_specs(func_state, flink_state) semantics:, O(n), where n is number of funcSpecs (implicity valueSpec)
#           -> flink give us all the state it knows about
#           -> our funcState provides an global "func_spec_name" => state_spec mapping
#           -> Current solution iterates over funcState to find value state... (This is alright)
#      -> extractKnownStateFromSpec(funcAddress, functionSpec, flinkStateValState)
#           -> an functionAddress (funcType)
#           -> global functionSpec
#           -> flinkState (key'd by state_name)  
#
#  -> Change Delta:
#   -> refactor extractKnownStateFromSpec logic a bit:
#       -> we known funcAddress.func_type is the "key" here. Just perform an lookup for this given function
#       -> Data access pattern:
#           -> 
defmodule StateFuncStorageTest do
    use ExUnit.Case
    alias StateFun
    
    @state_fun_int_type "io.statefun.types/int"

    @state_spec  %StateFun.ValueSpecs{name: "counter", type: @state_fun_int_type}
    @typed_value StateFun.TypedValue.from_int(20)

    @func_spec_stateless %StateFun.FunctionSpecs{type_name: "func_stateless", function_callback: nil, state_value_specs: nil}
    @func_spec_stateful %StateFun.FunctionSpecs{type_name: "func_stateful", function_callback: nil, state_value_specs: @state_spec}
  

    # Blank state, should notify Flink about state specs not registered
    test "received blank state from Apache Flink" do 
        {:ok, init_state} = StateFun.init([@func_spec_stateless, @func_spec_stateful])

        missing_specs = StateFun.find_missing_value_specs(init_state, %{})
        assert map_size(missing_specs) == 1
        assert Map.has_key?(missing_specs, "counter")        
    end

    # Ok, wow TIL but this is returning an nil. Not sure how the when guard didn't crash
    test "received correct state from Flink" do 
        {:ok, init_state} = StateFun.init([@func_spec_stateless, @func_spec_stateful])

        missing_specs = StateFun.find_missing_value_specs(init_state, %{"counter" => nil})
        assert missing_specs == nil
    end

    test "d should extract known state from specs (for stateful funcs)" do
        {:ok, init_state} = StateFun.init([@func_spec_stateless, @func_spec_stateful])
        func_addr = StateFun.Address.init("com.test", "func_stateful", "1")
        storage_object = StateFun.Address.AddressedScopedStorage.convertFlinkStateIntoFunctionScopedStorage(func_addr, init_state, %{"counter" => @typed_value})

        assert storage_object != nil
        assert map_size(storage_object.cells) == 1
        assert storage_object.cells["counter"].state_status == :UNMODIFIED
    end

end