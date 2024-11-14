defmodule Io.Statefun.Sdk.Egress.KinesisEgressRecord do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :partition_key, 1, type: :string, json_name: "partitionKey"
  field :value_bytes, 2, type: :bytes, json_name: "valueBytes"
  field :stream, 3, type: :string
  field :explicit_hash_key, 4, type: :string, json_name: "explicitHashKey"
end