extends BTNode
class_name BTDecorator

@export var child: BTNode

func tick(instance: BTInstance, delta: float) -> int:
	if not child:
		return Status.FAILURE
	return _tick_decorator(instance, delta)

# 子类实现具体逻辑
func _tick_decorator(instance: BTInstance, delta: float) -> int:
	return child.tick(instance, delta)

func reset(instance: BTInstance) -> void:
	_clear_storage(instance)
	if child:
		child.reset(instance)
