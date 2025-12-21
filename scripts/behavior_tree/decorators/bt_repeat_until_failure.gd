extends BTDecorator
class_name BTRepeatUntilFailure

## 重复直到失败节点
## 职责：循环执行子节点，直到子节点返回 FAILURE
##
## 原理：
## - 如果子节点返回 SUCCESS 或 RUNNING，继续执行
## - 如果子节点返回 FAILURE，停止循环并返回 SUCCESS（表示"循环已结束"）
## - 每次循环都会重新执行子节点（重置状态）
##
## 注意：
## - 失败时返回 SUCCESS 是为了让父 Sequence 继续执行后续节点（如 Cooldown）
## - 如果需要区分"成功结束"和"失败结束"，可以在黑板上设置标记
##
## 用途：
## - 连击系统：循环执行连击段，直到某一段超时失败，然后执行 CD
## - 持续技能：循环执行某个动作，直到条件不满足

## 完成时返回 SUCCESS 还是 FAILURE
@export var return_success: bool = true

func _tick_decorator(instance: BTInstance, delta: float) -> int:
	if not child:
		return Status.FAILURE
	
	var result = child.tick(instance, delta)
	
	match result:
		Status.RUNNING:
			# 子节点还在运行，继续等待
			return Status.RUNNING
		
		Status.SUCCESS:
			# 子节点成功，重置并继续循环
			child.reset(instance)
			# 继续下一帧执行（循环）
			return Status.RUNNING
		
		Status.FAILURE:
			# 子节点失败，停止循环
			# 返回 SUCCESS 表示"循环已正常结束"（无论成功还是失败）
			# 这样父 Sequence 可以继续执行后续节点（如 Cooldown）
			child.reset(instance)
			reset(instance)
			if return_success:
				return Status.SUCCESS
			else:
				return Status.FAILURE
	
	return Status.FAILURE
