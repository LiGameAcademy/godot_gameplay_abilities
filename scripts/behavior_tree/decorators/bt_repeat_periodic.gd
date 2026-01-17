extends BTDecorator
class_name BTRepeatPeriodic

## 周期性重复执行节点
## 每隔指定时间执行一次子节点，直到子节点返回 FAILURE
##
## 工作原理：
## 1. 执行子节点（通常是 BTSequence）
## 2. 如果子节点返回 RUNNING，继续等待子节点完成
## 3. 如果子节点返回 SUCCESS，重置子节点，开始计时，计时完成后继续执行
## 4. 如果子节点返回 FAILURE，停止重复，返回配置的返回值（默认 SUCCESS）
##
## 用途：
## - 周期性检查消耗（如献祭技能每秒检查生命值）
## - 周期性执行效果（如献祭技能每秒对周围敌人造成伤害）
## - 周期性更新状态（如引导技能每 tick 更新）

@export_group("Periodic Settings")
## 周期时间（秒）
## 如果设置了 period_key，优先从黑板读取；否则使用此值
@export var period: float = 1.0
## 从黑板读取周期时间的 Key（可选，如果设置则优先使用）
## 用途：允许 Modifier 在运行时修改周期时间（如天赋系统）
@export var period_key: String = ""
## 是否在首次进入时立即执行一次（true）还是等待第一个周期（false）
@export var execute_immediately: bool = true
## 当子节点返回 FAILURE 时，此节点返回什么状态
## - true: 返回 SUCCESS（表示周期性任务正常结束，如消耗不足时正常关闭技能）
## - false: 返回 FAILURE（表示周期性任务异常结束）
@export var return_success_on_failure: bool = true

func _tick_decorator(instance: BTInstance, delta: float) -> int:
	if not is_instance_valid(child):
		return Status.FAILURE
	
	# 获取实际的周期时间（优先从黑板读取）
	var actual_period = _get_actual_period(instance)
	
	# 获取运行时状态（亨元模式）
	var state = _get_state(instance)
	
	# 如果正在等待周期时间，更新计时器
	if state.is_waiting_for_period:
		state.elapsed += delta
		if state.elapsed >= actual_period:
			# 周期时间到达，重置计时器，准备执行子节点
			state.elapsed -= actual_period
			state.is_waiting_for_period = false
			_set_state(instance, state)  # 保存状态
			child.reset(instance)  # 重置子节点，准备下一轮执行
		else:
			# 还在等待周期时间，保存状态并返回
			_set_state(instance, state)
			return Status.RUNNING
	
	# 检查是否应该立即执行（首次执行）
	if not state.has_executed_first and execute_immediately:
		state.has_executed_first = true
		_set_state(instance, state)  # 保存状态
		# 立即执行，不等待周期
	
	# 执行子节点
	var result = child.tick(instance, delta)
	
	# 处理子节点的执行结果
	match result:
		Status.RUNNING:
			# 子节点还在运行，继续等待
			return Status.RUNNING
		
		Status.SUCCESS:
			# 子节点执行成功，重置子节点，开始计时
			child.reset(instance)
			state.is_waiting_for_period = true
			state.elapsed = 0.0
			_set_state(instance, state)  # 保存状态
			# 继续运行，等待周期时间
			return Status.RUNNING
		
		Status.FAILURE:
			# 子节点执行失败（如消耗不足），停止重复
			child.reset(instance)
			# 根据配置返回成功或失败
			if return_success_on_failure:
				return Status.SUCCESS
			else:
				return Status.FAILURE
	
	return Status.RUNNING

func _enter(instance: BTInstance) -> void:
	# 初始化运行时状态（亨元模式：存储在 BTInstance 中）
	var state = {
		"elapsed": 0.0,
		"is_waiting_for_period": false,
		"has_executed_first": execute_immediately  # 如果立即执行，标记为已执行
	}
	_set_state(instance, state)

func _exit(instance: BTInstance) -> void:
	# 清理运行时状态（亨元模式：由父类自动清理，这里可以显式清理）
	_clear_storage(instance)

## 获取运行时状态（亨元模式：状态存储在 BTInstance 中）
func _get_state(instance: BTInstance) -> Dictionary:
	return _get_storage(instance, {
		"elapsed": 0.0,
		"is_waiting_for_period": false,
		"has_executed_first": false
	})

## 设置运行时状态
func _set_state(instance: BTInstance, state: Dictionary) -> void:
	_set_storage(instance, state)

## 获取实际的周期时间（优先从黑板读取）
## [param] instance: BTInstance 行为树实例
## [return] float 周期时间（秒）
func _get_actual_period(instance: BTInstance) -> float:
	# 如果设置了 period_key，优先从黑板读取
	if not period_key.is_empty():
		var blackboard_period = instance.blackboard.get_var(period_key)
		if blackboard_period != null and blackboard_period is float:
			return blackboard_period as float
	# 否则使用配置的 period
	return period
