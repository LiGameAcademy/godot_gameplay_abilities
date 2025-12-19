extends BTNode
class_name BTComposite

@export var children: Array[BTNode] = []

func reset(instance: BTInstance) -> void:
	# 组合节点重置时，通常只需要清理自己的索引
	# 具体子节点的重置由 tick 逻辑中的切换动作触发，或者在这里递归重置（视需求而定）
	_clear_storage(instance)
	for child in children:
		child.reset(instance)
