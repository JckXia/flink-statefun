defmodule StateFun.Message do
    defstruct [targetAddress: nil, typedValue: nil]
    ## TODO replacing the existing Message decoding with this
    def is_int(message) do
        is(message, StateFun.IntType)
    end
    
    def as_int(message) do
        as(message, StateFun.IntType)
    end

    def is(message, type) do
        message.typedValue.typename == type.type_name()
    end

    def as(message, type) do
        typed_value = message.typedValue
        type.type_serializer.deserialize(typed_value.value)
    end

    def build(targetAddr, value, type) do
        type_serializer = type.type_serializer
        serialized_value = type_serializer.serialize(value)

        typed_value = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: type.type_name, has_value: true, value: serialized_value}
        %__MODULE__{targetAddress: targetAddr, typedValue: typed_value}
    end
end

defmodule StateFun.KafkaProducerRecord do
    defstruct [key: nil, topic: nil, value: nil, namespace: nil, type: nil]
    @kafka_typename "type.googleapis.com/io.statefun.sdk.egress.KafkaProducerRecord"


    def with_topic(record, topic) do
        %__MODULE__{record |  topic: topic }    
    end

    def with_key(record, key) do
        %__MODULE__{record | key: key }
    end

    def with_value(record, value) do
        %__MODULE__{record | value: value }
    end

    def for_egress(namespace, type) do
        %__MODULE__{namespace: namespace, type: type}
    end

    def build(producer_record) do
        namespace = producer_record.namespace
        type = producer_record.type
        pb_record = %Io.Statefun.Sdk.Egress.KafkaProducerRecord{key: producer_record.key, topic: producer_record.topic, value_bytes: producer_record.value}
        raw_val = Io.Statefun.Sdk.Egress.KafkaProducerRecord.encode(pb_record)
        egress_typed_val = %Io.Statefun.Sdk.Reqreply.TypedValue{typename: @kafka_typename, has_value: true, value: raw_val}
        %Io.Statefun.Sdk.Reqreply.FromFunction.EgressMessage{egress_namespace: namespace, egress_type: type, argument: egress_typed_val}
    end
end

defmodule StateFun.EgressMessage do 
    defstruct [:typename, :payload]
     def init(typename, payload) do 
        %__MODULE__{typename: typename, payload: payload}
    end
end