  # An internal, 3-uple object, tracks state information
    #   -> on set, status mutates to MODIFIY
    #   -> on remove, status mutates to DELETE
defmodule StateFun.Address.AddressedScopedStorage.Cell do 
    defstruct [state_value: nil, state_status: :UNMODIFIED]

        # TBD. This assumes the valueSpec matches up with the TypedValue we are deserializing
        #   -> What if user passes an valueSpec that doesn't quite match up?
        #       -> Need an error handling comb over, and look at what Java SDK is doing
    def get_internal(cell, valueSpec) do
        if cell.state_value == nil do
            nil
        else
            valueSpec.type.type_serializer.deserialize(cell.state_value.value)
        end
    end

    def set_internal(cell, valueSpec, value) do
        new_value = valueSpec.type.type_serializer.serialize(value)
            new_typed_val = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: valueSpec.type.type_name, has_value: true,  value: new_value}
            %__MODULE__{ cell | state_value: new_typed_val, state_status: :MODIFY}
        end

        def delete_internal(cell) do
            %__MODULE__{ cell | state_value: nil, state_status: :DELETE}
        end
    end
    
defmodule StateFun.Address.AddressedScopedStorage do
        # Todo: Cell is a map, but can easily be an list
    defstruct [:cells]
        
        # Assume valueSpec.name is found
    def get(storage, valueSpec) do
        get_target_cell(storage, valueSpec)
        |> StateFun.Address.AddressedScopedStorage.Cell.get_internal(valueSpec)
    end
        
        # ValueSpec<T>, T
    def set(storage, valueSpec, value) do           
        new_cell = get_target_cell(storage, valueSpec)
            |> StateFun.Address.AddressedScopedStorage.Cell.set_internal(valueSpec, value)
                    
        updated_cells = Map.put(storage.cells, valueSpec.name, new_cell)
        %{storage | cells: updated_cells }    
    end

    def remove(storage, valueSpec) do
        deleted_cell = get_target_cell(storage, valueSpec)
                        |> StateFun.Address.AddressedScopedStorage.Cell.delete_internal()
        updated_cells = Map.put(storage.cells, valueSpec.name, deleted_cell)
        %{storage | cells: updated_cells}
    end
        
        # TODO, err handling?
    defp get_target_cell(storage, valueSpec) do
        storage.cells[valueSpec.name]
    end

        # Semantic: Using the functionSpec pointed to by funcAddress (as a template), construct an object
        #   containing the valueSpec name mapped to actual state sent by Flink
    def convertFlinkStateIntoFunctionScopedStorage(funcAddress, functionSpec, stateReceivedFromFlink) do
        functionSpec[funcAddress.func_type]
        |> generate_cells_from_function_spec(stateReceivedFromFlink)
    end

    defp generate_cells_from_function_spec(target_function_spec, stateReceivedFromFlink) when length(target_function_spec.state_value_specs) == 0 do
        %__MODULE__{cells: %{}}
    end
        
    defp generate_cells_from_function_spec(target_function_spec, stateReceivedFromFlink) do
        state_spec_lst = target_function_spec.state_value_specs
            
        cells = generate_cells_from_value_spec_list(state_spec_lst, stateReceivedFromFlink, %{})
        %__MODULE__{cells: cells}
    end
    
    defp generate_cells_from_value_spec_list([], _stateReceivedFromFlink, cells) do
        cells
    end
        
    defp generate_cells_from_value_spec_list([state_value_spec | tail] = _state_spec_list, stateReceivedFromFlink, cells) do
        state_name = state_value_spec.name
        state_val_supplied_by_flink = stateReceivedFromFlink[state_name]
        new_cell = %StateFun.Address.AddressedScopedStorage.Cell{state_value: state_val_supplied_by_flink}
        cells = Map.put(cells, state_name, new_cell)
        generate_cells_from_value_spec_list(tail, stateReceivedFromFlink, cells)
    end
end