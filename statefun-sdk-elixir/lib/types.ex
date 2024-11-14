# What is the puropose of this file?
#   -> Type annotation, should also provide a way to serialize/deserialize some values
#   -> Hmm. not quite? Seems like the envelope passing serializtion/deserialziton occurs at app code level
#
# Why?
#   -> In theory, we need a way to serialize/deserialize state
#       -> But how is this ipml in SDK?
#   ->

# Code trace:
#   -> pb stands for protobuf

defmodule Types do
    @bOOLEAN_TYPENAME "io.statefun.types/bool"
    # @INTEGER_TYPENAME = "io.statefun.types/int"
    # @FLOAT_TYPENAME = "io.statefun.types/float"
    # @STRING_TYPENAME = "io.statefun.types/string"
    
end