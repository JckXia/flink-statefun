defmodule StateFuncStorageTest do
    use ExUnit.Case
    alias StateFun
    
    # Use ExUnit.Case to define test cases
    @state_fun_int_type "io.statefun.types/int"
    @state_name "counter"
    @typed_value StateFun.TypedValue.from_int(20)
    @indexed_state_recv_from_flink %{@state_name => @typed_value}
    @indexed_empty_state_recv_from_flink %{@state_name => nil}

    @func_addr StateFun.Address.init("com.test.funcs","agg_func", "1")
    @counter_state_spec  %StateFun.ValueSpecs{name: @state_name, type: "sfixed32"}
     
    test "Should generate an storage object (StateFun.Address.AddressedScopedStorage)" do
        func_spec = %StateFun.FunctionSpecs{type_name: "agg_func", function_callback: fn a -> 2 end, state_value_specs: @counter_state_spec}
        {:ok, init_state } = StateFun.init([func_spec])

        storage = StateFun.Address.AddressedScopedStorage.get_cells(@func_addr, init_state, @indexed_state_recv_from_flink)
        assert storage != nil
        assert map_size(storage.cells) == 1
    end


    test "Should generate an storage object when state is empty (StateFun.Address.AddressedScopedStorage)" do
        func_spec = %StateFun.FunctionSpecs{type_name: "agg_func", function_callback: fn a -> 2 end, state_value_specs: @counter_state_spec}
        {:ok, init_state } = StateFun.init([func_spec])

        storage = StateFun.Address.AddressedScopedStorage.get_cells(@func_addr, init_state, @indexed_empty_state_recv_from_flink)
        assert storage != nil
        assert storage.cells[@state_name].state_value == nil
    end

    test "Should get the value from an Storage object" do
        func_spec = %StateFun.FunctionSpecs{type_name: "agg_func", function_callback: fn a -> 2 end, state_value_specs: @counter_state_spec}
        {:ok, init_state } = StateFun.init([func_spec])

        storage = StateFun.Address.AddressedScopedStorage.get_cells(@func_addr, init_state, @indexed_state_recv_from_flink)
        
        # Equivalent to ctx.storage().get(ValueSpec) in the Java SDK
        res = storage 
                |> StateFun.Address.AddressedScopedStorage.get(@counter_state_spec)

        assert res == 20
    end

    test "Should set the value from an storage object" do
        func_spec = %StateFun.FunctionSpecs{type_name: "agg_func", function_callback: fn a -> 2 end, state_value_specs: @counter_state_spec}
        {:ok, init_state } = StateFun.init([func_spec])

        storage = StateFun.Address.AddressedScopedStorage.get_cells(@func_addr, init_state, @indexed_state_recv_from_flink)
        # Equivalent to ctx.storage().set(value_spec, value)
        storage = storage 
            |> StateFun.Address.AddressedScopedStorage.set(@counter_state_spec, 120)
        
        assert storage != nil
        assert map_size(storage.cells) == 1

        updated_cell = storage.cells[@state_name]
        assert updated_cell != nil
        assert updated_cell.state_status == :MODIFIED
        
        res = 
        storage 
        |> StateFun.Address.AddressedScopedStorage.get(@counter_state_spec)

        assert res == 120
    end

end