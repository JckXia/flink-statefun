defmodule Io.Statefun.Sdk.Types.BooleanWrapper do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :value, 1, type: :bool
end

defmodule Io.Statefun.Sdk.Types.IntWrapper do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :value, 1, type: :sfixed32
end

defmodule Io.Statefun.Sdk.Types.FloatWrapper do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :value, 1, type: :float
end

defmodule Io.Statefun.Sdk.Types.LongWrapper do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :value, 1, type: :sfixed64
end

defmodule Io.Statefun.Sdk.Types.DoubleWrapper do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :value, 1, type: :double
end

defmodule Io.Statefun.Sdk.Types.StringWrapper do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :value, 1, type: :string
end