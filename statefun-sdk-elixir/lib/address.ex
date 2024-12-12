defmodule StateFun.Address do 
    defstruct [:func_namespace, :func_type, :func_id]
    def init(func_namespace, func_type, func_id) do
        %__MODULE__{func_namespace: func_namespace, func_type: func_type, func_id: func_id}
    end
end