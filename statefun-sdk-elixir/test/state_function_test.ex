defmodule StateFuncTest do
  use ExUnit.Case
  
  # Use ExUnit.Case to define test cases


  test "should be able to initialize an StateFun master struct" do
    
    state_value_spec = %StateFun.ValueSpecs{name: "counter", type: "int"}
    function_spec = %StateFun.FunctionSpecs{type_name: "enriched-event-handler", function_callback: &add/2, state_value_specs: state_value_spec}
    {:ok, pid} = GenServer.start_link(StateFun, [function_spec])
  end

  defp add(context, message) do 
     message = message + 2
    %{context | eggress: message}
  end
end