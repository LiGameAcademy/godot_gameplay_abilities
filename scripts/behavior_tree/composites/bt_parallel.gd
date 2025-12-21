extends BTComposite
class_name BTParallel

## 并行执行节点
## 同时执行所有子节点，根据策略决定返回状态
##
## 策略：
## - SUCCEED_ON_ONE: 任意一个子节点成功即返回成功
## - SUCCEED_ON_ALL: 所有子节点成功才返回成功
## - FAIL_ON_ONE: 任意一个子节点失败即返回失败
## - FAIL_ON_ALL: 所有子节点失败才返回失败

enum Policy {
	SUCCEED_ON_ONE,  ## 任意一个成功即成功
	SUCCEED_ON_ALL,  ## 所有成功才成功
	FAIL_ON_ONE,     ## 任意一个失败即失败
	FAIL_ON_ALL      ## 所有失败才失败
}

@export var policy: Policy = Policy.SUCCEED_ON_ALL

func _tick(instance: BTInstance, delta: float) -> int:
	var success_count = 0
	var failure_count = 0
	var running_count = 0
	
	# 并行执行所有子节点
	for child in children:
		var result = child.tick(instance, delta)
		
		match result:
			Status.SUCCESS:
				success_count += 1
			Status.FAILURE:
				failure_count += 1
			Status.RUNNING:
				running_count += 1
	
	# 根据策略决定返回状态
	match policy:
		Policy.SUCCEED_ON_ONE:
			if success_count > 0:
				# 至少一个成功，清理所有子节点状态
				_reset_all_children(instance)
				return Status.SUCCESS
			elif failure_count == children.size():
				# 全部失败
				_reset_all_children(instance)
				return Status.FAILURE
			else:
				# 还有节点在运行
				return Status.RUNNING
		
		Policy.SUCCEED_ON_ALL:
			if success_count == children.size():
				# 全部成功
				_reset_all_children(instance)
				return Status.SUCCESS
			elif failure_count > 0:
				# 至少一个失败
				_reset_all_children(instance)
				return Status.FAILURE
			else:
				# 还有节点在运行
				return Status.RUNNING
		
		Policy.FAIL_ON_ONE:
			if failure_count > 0:
				# 至少一个失败
				_reset_all_children(instance)
				return Status.FAILURE
			elif success_count == children.size():
				# 全部成功
				_reset_all_children(instance)
				return Status.SUCCESS
			else:
				# 还有节点在运行
				return Status.RUNNING
		
		Policy.FAIL_ON_ALL:
			if failure_count == children.size():
				# 全部失败
				_reset_all_children(instance)
				return Status.FAILURE
			elif success_count > 0:
				# 至少一个成功
				_reset_all_children(instance)
				return Status.SUCCESS
			else:
				# 还有节点在运行
				return Status.RUNNING
	
	return Status.RUNNING

## 重置所有子节点
func _reset_all_children(instance: BTInstance) -> void:
	for child in children:
		child.reset(instance)

