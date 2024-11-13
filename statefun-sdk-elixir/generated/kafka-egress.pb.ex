defmodule Io.Statefun.Sdk.Egress.KafkaProducerRecord do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :key, 1, type: :string
  field :value_bytes, 2, type: :bytes, json_name: "valueBytes"
  field :topic, 3, type: :string
end