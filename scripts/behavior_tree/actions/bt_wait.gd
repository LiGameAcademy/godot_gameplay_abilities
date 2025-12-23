extends BTNode
class_name BTWait

## 等待时间（秒）
## 如果设置了 duration_key，优先从黑板读取；否则使用此值
@export var duration: float = 1.0
## 从黑板读取等待时间的 Key（可选，如果设置则优先使用）
## 用途：允许 Modifier 在运行时修改等待时间（如天赋系统）
@export var duration_key: String = ""

# 我们不再需要手动判断 "是第一次进来吗？"
# 因为 _enter 给了我们初始化的机会

func _enter(instance: BTInstance):
	# 获取实际的等待时间（优先从黑板读取）
	var actual_duration = _get_actual_duration(instance)
	# 在进入时，直接记录结束时间到黑板
	# 这里利用 helper 函数 set_data
	var end_time = Time.get_ticks_msec() / 1000.0 + actual_duration
	_set_storage(instance, end_time)

## 获取实际的等待时间（优先从黑板读取）
## [param] instance: BTInstance 行为树实例
## [return] float 等待时间（秒）
func _get_actual_duration(instance: BTInstance) -> float:
	# 如果设置了 duration_key，优先从黑板读取
	if not duration_key.is_empty():
		var blackboard_duration = instance.blackboard.get_var(duration_key)
		if blackboard_duration != null and blackboard_duration is float:
			return blackboard_duration as float
	# 否则使用配置的 duration
	return duration

func _tick(instance: BTInstance, delta: float) -> int:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time >= _get_storage(instance):
		return Status.SUCCESS
	
	return Status.RUNNING

# 不需要 _exit，因为 blackboard.erase_var(self) 会由父类 tick 自动处理
