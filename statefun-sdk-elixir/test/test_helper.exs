ExUnit.start(capture_log: true)

defmodule EventDispatchingService.TestHelper do
  def random_string(), do: random_string(10)

  def random_string(length),
    do: :crypto.strong_rand_bytes(length) |> :base64.encode() |> String.slice(0, length)

  def random_number(max \\ 100), do: :rand.uniform(max)

#   def string_keys(map) do
#     map |> Jason.encode!() |> Jason.decode!()
#   end
end