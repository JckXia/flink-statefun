defmodule Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueMutation.MutationType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :DELETE, 0
  field :MODIFY, 1
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.ExpirationSpec.ExpireMode do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :NONE, 0
  field :AFTER_WRITE, 1
  field :AFTER_INVOKE, 2
end

defmodule Io.Statefun.Sdk.Reqreply.Address do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :namespace, 1, type: :string
  field :type, 2, type: :string
  field :id, 3, type: :string
end

defmodule Io.Statefun.Sdk.Reqreply.TypedValue do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :typename, 1, type: :string
  field :has_value, 2, type: :bool, json_name: "hasValue"
  field :value, 3, type: :bytes
end

defmodule Io.Statefun.Sdk.Reqreply.ToFunction.PersistedValue do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :state_name, 1, type: :string, json_name: "stateName"
  field :state_value, 2, type: Io.Statefun.Sdk.Reqreply.TypedValue, json_name: "stateValue"
end

defmodule Io.Statefun.Sdk.Reqreply.ToFunction.Invocation do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :caller, 1, type: Io.Statefun.Sdk.Reqreply.Address
  field :argument, 2, type: Io.Statefun.Sdk.Reqreply.TypedValue
end

defmodule Io.Statefun.Sdk.Reqreply.ToFunction.InvocationBatchRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :target, 1, type: Io.Statefun.Sdk.Reqreply.Address
  field :state, 2, repeated: true, type: Io.Statefun.Sdk.Reqreply.ToFunction.PersistedValue
  field :invocations, 3, repeated: true, type: Io.Statefun.Sdk.Reqreply.ToFunction.Invocation
end

defmodule Io.Statefun.Sdk.Reqreply.ToFunction do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  oneof :request, 0

  field :invocation, 100,
    type: Io.Statefun.Sdk.Reqreply.ToFunction.InvocationBatchRequest,
    oneof: 0
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueMutation do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :mutation_type, 1,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueMutation.MutationType,
    json_name: "mutationType",
    enum: true

  field :state_name, 2, type: :string, json_name: "stateName"
  field :state_value, 3, type: Io.Statefun.Sdk.Reqreply.TypedValue, json_name: "stateValue"
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.Invocation do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :target, 1, type: Io.Statefun.Sdk.Reqreply.Address
  field :argument, 2, type: Io.Statefun.Sdk.Reqreply.TypedValue
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.DelayedInvocation do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :is_cancellation_request, 10, type: :bool, json_name: "isCancellationRequest"
  field :cancellation_token, 11, type: :string, json_name: "cancellationToken"
  field :delay_in_ms, 1, type: :int64, json_name: "delayInMs"
  field :target, 2, type: Io.Statefun.Sdk.Reqreply.Address
  field :argument, 3, type: Io.Statefun.Sdk.Reqreply.TypedValue
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.EgressMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :egress_namespace, 1, type: :string, json_name: "egressNamespace"
  field :egress_type, 2, type: :string, json_name: "egressType"
  field :argument, 3, type: Io.Statefun.Sdk.Reqreply.TypedValue
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.InvocationResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :state_mutations, 1,
    repeated: true,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueMutation,
    json_name: "stateMutations"

  field :outgoing_messages, 2,
    repeated: true,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.Invocation,
    json_name: "outgoingMessages"

  field :delayed_invocations, 3,
    repeated: true,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.DelayedInvocation,
    json_name: "delayedInvocations"

  field :outgoing_egresses, 4,
    repeated: true,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.EgressMessage,
    json_name: "outgoingEgresses"
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.ExpirationSpec do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :mode, 1,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.ExpirationSpec.ExpireMode,
    enum: true

  field :expire_after_millis, 2, type: :int64, json_name: "expireAfterMillis"
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueSpec do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :state_name, 1, type: :string, json_name: "stateName"

  field :expiration_spec, 2,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.ExpirationSpec,
    json_name: "expirationSpec"

  field :type_typename, 3, type: :string, json_name: "typeTypename"
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction.IncompleteInvocationContext do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  field :missing_values, 1,
    repeated: true,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.PersistedValueSpec,
    json_name: "missingValues"
end

defmodule Io.Statefun.Sdk.Reqreply.FromFunction do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.13.0", syntax: :proto3

  oneof :response, 0

  field :invocation_result, 100,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.InvocationResponse,
    json_name: "invocationResult",
    oneof: 0

  field :incomplete_invocation_context, 101,
    type: Io.Statefun.Sdk.Reqreply.FromFunction.IncompleteInvocationContext,
    json_name: "incompleteInvocationContext",
    oneof: 0
end