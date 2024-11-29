# Functions of interest
#   -> extractKnownStateFromSpec
#   -> find_missing_value_specs

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

    test "should extract known state from specs (for stateful funcs)" do
        {:ok, init_state} = StateFun.init([@func_spec_stateless, @func_spec_stateful])
        func_addr = StateFun.Address.init("com.test", "func_stateful", "1")
        storage_object = StateFun.Address.AddressedScopedStorage.extractKnownStateFromSpec(func_addr, init_state, %{"counter" => @typed_value})
        assert storage_object != nil
        assert map_size(storage_object.cells) == 1
        assert storage_object.cells["counter"].state_status == :UNMODIFIED
    end

end