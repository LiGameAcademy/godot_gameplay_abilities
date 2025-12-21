extends BTAction
class_name AbilityNodeSetComboExpiry

## 设置连击过期时间节点
## 职责：设置连击窗口期的截止时间戳
##
## 原理：
## - 计算当前时间 + 窗口期时长
## - 将结果写入黑板的 combo_expiry_time
## - 用于 BTSwitch 的超时重置逻辑

@export var window_duration: float = 0.8 ## 连击窗口期（秒）
@export var expiry_key: String = "combo_expiry_time" ## 过期时间在黑板中的 Key

func _tick(instance: BTInstance, delta: float) -> int:
	var blackboard = instance.blackboard
	
	# 计算过期时间（毫秒时间戳）
	var now = Time.get_ticks_msec()
	var expiry_time = now + int(window_duration * 1000.0)
	
	# 写入黑板
	blackboard.set_var(expiry_key, expiry_time)
	
	return Status.SUCCESS

