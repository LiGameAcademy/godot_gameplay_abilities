extends BTDecorator
class_name BTCooldown

## 冷却节点
## 检查黑板中的变量是否大于指定的值

@export var cooldown_time: float = 5.0

func _tick_decorator(instance: BTInstance, delta: float) -> int:
	# 获取上次完成的时间戳 (存储在 blackboard 中，使用 self 作为 key)
	# 注意：这里需要依赖一个全局时间或累积时间，简单起见用 OS.get_ticks_msec()
	var last_time = _get_storage(instance, -999999.0)
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_time < cooldown_time:
		return Status.FAILURE # 还在冷却中
		
	# 执行子节点
	var result = child.tick(instance, delta)
	
	# 只有子节点成功(或失败，看需求)后，才重置冷却
	if result == Status.SUCCESS or result == Status.FAILURE:
		_set_storage(instance, current_time)
		
	return result
