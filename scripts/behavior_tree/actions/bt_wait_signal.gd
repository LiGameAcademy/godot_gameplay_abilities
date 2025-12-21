extends BTAction
class_name BTWaitSignal

## 基于观察者模式的等待节点
## 职责：挂起行为树，直到收到黑板变量变更通知，或超时

@export var signal_key: String = "event_input_received"
@export var timeout: float = 0.8
@export var consume_signal: bool = true

func _enter(instance: BTInstance) -> void:
	_set_signal_triggered(instance, false)
	_set_elapsed(instance, 0.0)
	
	# 1. 【核心】注册观察者
	# 利用 BTInstance 现有的观察者系统，告诉它："signal_key 变了请通知我"
	if instance.has_method("register_observer"):
		instance.register_observer(self)
		
	# 进入时先检查一次（防止信号在上一帧已经触发了）
	if _get_var(instance, signal_key, false):
		_set_signal_triggered(instance, true)

func _exit(instance: BTInstance) -> void:
	# 2. 【核心】注销观察者
	if instance.has_method("unregister_observer"):
		instance.unregister_observer(self)

func _tick(instance: BTInstance, delta: float) -> int:
	# A. 检查是否触发了信号 (由回调函数修改)
	if _get_signal_triggered(instance):
		# 注意：在返回 SUCCESS 之前消费信号，确保下一段能够正确接收新的信号
		if consume_signal:
			# 先重置信号触发状态，再设置变量为 false
			# 这样可以避免在退出时再次触发信号
			_set_signal_triggered(instance, false)
			instance.blackboard.set_var(signal_key, false)
		return Status.SUCCESS
	
	# B. 检查超时
	_set_elapsed(instance, _get_elapsed(instance) + delta)
	if _get_elapsed(instance) >= timeout:
		return Status.FAILURE
		
	return Status.RUNNING

#region ========== 观察者接口 ==========

## [回调] 当黑板数据改变时，由 Instance 调用
## 这是一个"被动"的检查，比每帧主动查询更高效、响应更快
func on_blackboard_change(instance: BTInstance, key: String) -> void:
	if key == signal_key:
		# 检查值是否为 true
		if _get_var(instance, key, false):
			_set_signal_triggered(instance, true)
			# 注意：我们不能在这里直接 return Status，
			# 必须修改状态变量，等待下一次 _tick 返回

#endregion

func _set_signal_triggered(instance: BTInstance, value: bool) -> void:
	var storage = _get_storage(instance, {})
	if not storage is Dictionary:
		storage = {}
	var storage_dict = storage as Dictionary
	storage_dict["signal_triggered"] = value
	_set_storage(instance, storage_dict)

func _get_signal_triggered(instance: BTInstance) -> bool:
	var storage = _get_storage(instance, {})
	if not storage is Dictionary:
		return false
	var storage_dict = storage as Dictionary
	return storage_dict.get("signal_triggered", false)

func _set_elapsed(instance: BTInstance, value: float) -> void:
	var storage = _get_storage(instance, {})
	if not storage is Dictionary:
		storage = {}
	var storage_dict = storage as Dictionary
	storage_dict["elapsed"] = value
	_set_storage(instance, storage_dict)

func _get_elapsed(instance: BTInstance) -> float:
	var storage = _get_storage(instance, {})
	if not storage is Dictionary:
		return 0.0
	var storage_dict = storage as Dictionary
	return storage_dict.get("elapsed", 0.0)
