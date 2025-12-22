extends BTAction
class_name BTCheckVarAction

## 检查变量动作节点
## 检查黑板中的变量是否等于指定的值，返回 SUCCESS 或 FAILURE
##
## 用途：
## - 在 BTSelector 中作为条件判断
## - 检查切换类技能的操作类型（turn_on/turn_off）

@export var key: String = ""
@export var value: Variant = null
@export var check_exist_only: bool = false

func _tick(instance: BTInstance, delta: float) -> int:
	if key.is_empty():
		push_warning("BTCheckVarAction: key is empty!")
		return Status.FAILURE
	
	# 检查变量是否存在
	if not instance.blackboard.has_var(key):
		return Status.FAILURE
	
	# 如果只检查存在性，返回成功
	if check_exist_only:
		return Status.SUCCESS
	
	# 检查变量值是否匹配
	var var_value = instance.blackboard.get_var(key)
	if var_value == value:
		return Status.SUCCESS
	else:
		return Status.FAILURE
