extends BTAction
class_name AbilityNodeAdvanceCombo

## 推进连击索引节点
## 职责：在当前连击段完成后，推进到下一段，并设置连击窗口期
##
## 原理：
## - 将 combo_index 加 1，为下次触发做准备
## - 设置 combo_expiry_time，用于超时重置
## - 如果是终结技，可以选择重置索引或循环

@export var reset_timer: float = 1.0 ## 连击有效窗口期（秒）
@export var is_finisher: bool = false ## 是否是终结技
@export var combo_index_key: String = "combo_index" ## 连击索引在黑板中的 Key
@export var combo_expiry_time_key: String = "combo_expiry_time" ## 连击过期时间在黑板中的 Key

func _tick(instance: BTInstance, delta: float) -> int:
	var blackboard = instance.blackboard
	var current_index = blackboard.get_var(combo_index_key, 0)
	
	# 1. 推进索引
	# 如果是终结技，可以选择重置为 0（循环）或保持最大值（不允许继续）
	# 这里我们选择循环模式：终结技后重置为 0
	if is_finisher:
		blackboard.set_var(combo_index_key, 0)
	else:
		blackboard.set_var(combo_index_key, current_index + 1)
	
	# 2. 记录绝对截止时间戳 (毫秒)
	# 只有在非终结技时才设置过期时间（终结技后应该立即重置）
	if not is_finisher:
		var now = Time.get_ticks_msec()
		var expiry_time = now + int(reset_timer * 1000.0)
		blackboard.set_var(combo_expiry_time_key, expiry_time)
	else:
		# 终结技后清除过期时间，允许立即重新开始连击
		blackboard.set_var(combo_expiry_time_key, 0)
	
	return Status.SUCCESS
