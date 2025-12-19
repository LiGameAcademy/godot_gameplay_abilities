extends BTNode
class_name BTWait

@export var duration: float = 1.0

# 我们不再需要手动判断 "是第一次进来吗？"
# 因为 _enter 给了我们初始化的机会

func _enter(instance: BTInstance):
	# 在进入时，直接记录结束时间到黑板
	# 这里利用 helper 函数 set_data
	var end_time = Time.get_ticks_msec() / 1000.0 + duration
	_set_storage(instance, end_time)

func _tick(instance: BTInstance, delta: float) -> int:
	var end_time = _get_storage(instance)
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time >= end_time:
		return Status.SUCCESS
	
	return Status.RUNNING

# 不需要 _exit，因为 blackboard.erase_var(self) 会由父类 tick 自动处理
