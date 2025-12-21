extends BTComposite
class_name BTSwitch

## 根据黑板变量的值，选择执行对应的子节点
## 类似于编程语言中的 switch(index) case 0: run_child(0)...

@export var variable_key: String = "switch_index"

func _tick(instance: BTInstance, delta: float) -> int:
	var blackboard = instance.blackboard
	
	# 获取当前索引
	var index = blackboard.get_var(variable_key, 0)
	
	# 边界检查
	if index < 0 or index >= children.size():
		# 索引越界，重置为 0（循环模式）
		index = 0
		blackboard.set_var(variable_key, 0)
	
	# 执行对应的子节点
	var child = children[index]
	return child.tick(instance, delta)
