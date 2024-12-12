defmodule StateFuncTest do
  use ExUnit.Case
  alias StateFun
  
  # Use ExUnit.Case to define test cases


  test "should be able to initialize an StateFun master struct" do
    
    state_value_spec = %StateFun.ValueSpecs{name: "counter", type: "int"}
    function_spec = %StateFun.FunctionSpecs{type_name: "enriched-event-handler", function_callback: &add/2, state_value_specs: state_value_spec}
    {:ok, pid} = GenServer.start_link(StateFun, [function_spec])
 
  end


  test "Context test" do
    
    state_value_spec = %StateFun.ValueSpecs{name: "counter", type: "int"}
    function_spec = %StateFun.FunctionSpecs{type_name: "enriched-event-handler", function_callback: &add/2, state_value_specs: state_value_spec}
    # {:ok, pid} = GenServer.start_link(StateFun, [function_spec])
    stateFunMsg = %StateFun.Message{}
    ctx = StateFun.Context.init(24, %{})

    ctx = StateFun.Context.send(ctx, stateFunMsg)

    ctx = ctx 
        |> StateFun.Context.send(stateFunMsg)
        |> StateFun.Context.send(stateFunMsg)

  end

  test "Message test" do
    basic_int = %Io.Statefun.Sdk.Types.IntWrapper{value: 12}
    encoded =  Io.Statefun.Sdk.Types.IntWrapper.encode(basic_int)
    typedValue = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: :sfixed32, has_value: true, value: encoded}
    
    message_envelope = %StateFun.Message{typedValue: typedValue}
    assert StateFun.Message.is_int(message_envelope) == true
    
    decoded_message = StateFun.Message.as_int(message_envelope)
    assert decoded_message == 12
  end

  test "State Test" do 
    state_value_spec = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: :sfixed32, has_value: true, value: "100111"}

    mock_state_1 = %Io.Statefun.Sdk.Reqreply.ToFunction.PersistedValue{state_name: "counter", state_value: state_value_spec}
    mock_state_2 = %Io.Statefun.Sdk.Reqreply.ToFunction.PersistedValue{state_name: "visitor", state_value: state_value_spec}

    result_mapping = StateFun.Address.AddressedScopedStorage.indexReceivedStateFromFlink([mock_state_1, mock_state_2])
  end

  test "when received state object from flink, but a function spec for the given function isn't present, report" do
    adder_func_spec = %StateFun.FunctionSpecs{type_name: "adder", function_callback: fn a -> 2 end, state_value_specs: nil}

    # TODO: Add a type annotation thingy to SDK so we aren't hard coding these magic vals everywhere
    counter_state_spec = %StateFun.ValueSpecs{name: "counter", type: "sfixed32"}
    aggregator_func_spec = %StateFun.FunctionSpecs{type_name: "aggreg",
                                                   function_callback: fn a -> 2 end, 
                                                   state_value_specs: counter_state_spec}

    
    {:ok, init_state } = StateFun.init([adder_func_spec, aggregator_func_spec])

    aggregator_func_addr = StateFun.Address.init("com.pd","aggreg","1")

    indexedFlinkState = StateFun.indexReceivedStateFromFlink([])
    missing_state = StateFun.find_missing_value_specs(init_state, indexedFlinkState)

    assert map_size(missing_state) == 1
    assert Map.has_key?(missing_state, "counter")
    assert missing_state["counter"].name == "counter"
    assert missing_state["counter"].type == "sfixed32"
  end

#   test "State Test PT2" do


#     state_value_spec = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: :sfixed32, has_value: true, value: "100111"}

#     mock_state_1 = %Io.Statefun.Sdk.Reqreply.ToFunction.PersistedValue{state_name: "counter", state_value: state_value_spec}
#     mock_state_2 = %Io.Statefun.Sdk.Reqreply.ToFunction.PersistedValue{state_name: "visitor", state_value: state_value_spec}

#     result_mapping = StateFun.Address.AddressedScopedStorage.indexReceivedStateFromFlink([mock_state_1, mock_state_2])

#     ##############

#     adder_func_spec = %StateFun.FunctionSpecs{type_name: "adder", function_callback: fn a -> 2 end, state_value_specs: nil}

#     # TODO: Add a type annotation thingy to SDK so we aren't hard coding these magic vals everywhere
#     counter_state_spec = %StateFun.ValueSpecs{name: "counter", type: "sfixed32"}
#     aggregator_func_spec = %StateFun.FunctionSpecs{type_name: "aggreg",
#                                                    function_callback: fn a -> 2 end, 
#                                                    state_value_specs: counter_state_spec}
#     {:ok, init_state } = StateFun.init([adder_func_spec, aggregator_func_spec])
#     storage_object = StateFun.Address.AddressedScopedStorage.extractKnownStateFromSpec(%{}, init_state, result_mapping)

#     assert Map.has_key?(storage_object, "counter")
#     assert storage_object["counter"].state_type == :sfixed32
# end 

# test "State TEst PT3" do
#     adder_func_spec = %StateFun.FunctionSpecs{type_name: "adder", function_callback: fn a -> 2 end, state_value_specs: nil}

#     # TODO: Add a type annotation thingy to SDK so we aren't hard coding these magic vals everywhere
#     counter_state_spec = %StateFun.ValueSpecs{name: "counter", type: "sfixed32"}
#     aggregator_func_spec = %StateFun.FunctionSpecs{type_name: "aggreg",
#                                                    function_callback: fn a -> 2 end, 
#                                                    state_value_specs: counter_state_spec}
#     {:ok, init_state } = StateFun.init([adder_func_spec, aggregator_func_spec])

#     indexed_flink_state = StateFun.Address.AddressedScopedStorage.indexReceivedStateFromFlink([])
 
#     func_addr = StateFun.Address.init("a","adder","C")
#     storage_object =  StateFun.Address.AddressedScopedStorage.extractKnownStateFromSpec(func_addr, init_state, indexed_flink_state)
#     IO.inspect("New storage object #{inspect(storage_object)}")
#     assert Map.has_key?(storage_object, "counter")
#     assert storage_object["counter"].state_type == "sfixed32"
# end

 test "Cell test" do 
    init_cell = StateFun.Address.AddressedScopedStorage.Cell.init(:sfixed32)
    assert init_cell.state_status == :UNMODIFIED
    assert init_cell.state_type == :sfixed32

    new_cell = StateFun.Address.AddressedScopedStorage.Cell.set(init_cell, 123)
    assert new_cell.state_status == :MODIFIED
    assert new_cell.state_type == :sfixed32
    assert new_cell.state_value == 123

    deleted_cell = StateFun.Address.AddressedScopedStorage.Cell.delete(init_cell)
    assert deleted_cell.state_status == :DELETED
    assert deleted_cell.state_type == :sfixed32
    assert deleted_cell.state_value == nil

 end


  defp add(context, message) do 
     message = message + 2
    %{context | eggress: message}
  end
end