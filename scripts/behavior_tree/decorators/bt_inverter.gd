extends BTDecorator
class_name BTInverter

func _tick_decorator(instance: BTInstance, delta: float) -> int:
	var result = child.tick(instance, delta)
	
	if result == Status.SUCCESS:
		return Status.FAILURE
	if result == Status.FAILURE:
		return Status.SUCCESS
		
	return Status.RUNNING
