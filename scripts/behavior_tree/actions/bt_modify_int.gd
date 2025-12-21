extends BTAction
class_name BTModifyInt

## 修改整数变量节点
## 修改黑板中的整数变量

enum Operation { 
    SET,                ## 设置为指定值
    ADD,                ## 增加指定值
    SUBTRACT            ## 减少指定值
}

@export var variable_key: String = ""   ## 变量键
@export var value: int = 1              ## 修改值
@export var operation: Operation = Operation.ADD  ## 操作

func _tick(instance: BTInstance, delta: float) -> int:
    var current_val: int = _get_var(instance, variable_key, 0)
    
    match operation:
        Operation.SET: current_val = value
        Operation.ADD: current_val += value
        Operation.SUBTRACT: current_val -= value

    _set_var(instance, variable_key, current_val)
    return Status.SUCCESS
