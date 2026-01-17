extends Node

## 技能事件总线（单例）
## 提供全局事件通讯机制，实现组件间的解耦
## 支持统一的事件触发接口的事件信号
##
## 使用方式：
## 1. 触发事件：AbilityEventBus.trigger_game_event(&"damage_applied", {"damage_info": info})
## 2. 监听所有事件：AbilityEventBus.game_event_occurred.connect(_on_event)
## 3. 监听特定事件（推荐，性能更好）：AbilityEventBus.subscribe_to_event(&"damage_applied", _on_damage)

# ========== 配置 ==========
## 是否启用调试日志
@export var enable_debug: bool = false

# ========== 统一游戏事件系统 ==========
## 统一游戏事件信号
## 所有游戏事件都通过此信号统一触发
## [param] event_type: StringName 事件类型，如 "damage_applied", "vital_modified" 等
## [param] context: Dictionary 事件上下文，包含事件相关的所有信息
signal game_event_occurred(event_type: StringName, context: Dictionary)

# ========== 事件过滤系统（性能优化） ==========
## 事件订阅者字典：event_type -> Array[Callable]
## 用于按事件类型过滤，避免所有监听者处理所有事件
var _event_subscribers: Dictionary[StringName, Array] = {}

# ========== 调试支持 ==========
## 事件日志（仅在 enable_debug = true 时记录）
var _event_log: Array[Dictionary] = []
## 最大日志条数
const MAX_LOG_ENTRIES: int = 100

# ========== 公共API ==========

## 触发游戏事件（统一接口）
## [param] event_type: StringName 事件类型，如 "damage_applied", "ability_learned" 等
## [param] context: Dictionary 事件上下文，包含事件相关的所有信息（可选，默认为空字典）
## 
## 示例：
## ```gdscript
## AbilityEventBus.trigger_game_event(&"damage_applied", {
##     "damage_info": damage_info,
##     "target": target,
##     "final_damage": 50.0
## })
## ```
func trigger_game_event(event_type: StringName, context: Dictionary = {}) -> void:
	# 输入验证
	if event_type.is_empty():
		push_error("AbilityEventBus: event_type cannot be empty")
		return
	
	if not context is Dictionary:
		push_error("AbilityEventBus: context must be a Dictionary, got %s" % typeof(context))
		return
	
	# 调试日志
	if enable_debug:
		_log_event(event_type, context)
	
	# 触发统一信号（向后兼容，所有监听者都会收到）
	game_event_occurred.emit(event_type, context)
	
	# 触发特定订阅者（性能优化，只通知关心此事件的监听者）
	if _event_subscribers.has(event_type):
		var subscribers = _event_subscribers[event_type]
		for callback in subscribers:
			if callback.is_valid():
				callback.call(event_type, context)
			else:
				# 清理无效的回调
				subscribers.erase(callback)

## 按事件类型订阅（推荐，性能更好）
## 只会在指定事件类型触发时调用回调，避免处理不相关的事件
## [param] event_type: StringName 要监听的事件类型
## [param] callback: Callable 回调函数，签名：func(event_type: StringName, context: Dictionary) -> void
## 
## 示例：
## ```gdscript
## AbilityEventBus.subscribe_to_event(&"damage_applied", _on_damage_applied)
## 
## func _on_damage_applied(event_type: StringName, context: Dictionary) -> void:
##     var damage_info = context.get("damage_info")
##     print("Damage applied: ", damage_info.final_damage)
## ```
func subscribe_to_event(event_type: StringName, callback: Callable) -> void:
	if event_type.is_empty():
		push_error("AbilityEventBus: event_type cannot be empty")
		return
	
	if not callback.is_valid():
		push_error("AbilityEventBus: callback is not valid")
		return
	
	if not _event_subscribers.has(event_type):
		_event_subscribers[event_type] = []
	
	_event_subscribers[event_type].append(callback)

## 取消事件订阅
## [param] event_type: StringName 事件类型
## [param] callback: Callable 要移除的回调函数
func unsubscribe_from_event(event_type: StringName, callback: Callable) -> void:
	if not _event_subscribers.has(event_type):
		return
	
	_event_subscribers[event_type].erase(callback)
	
	# 如果该事件类型没有订阅者了，清理字典
	if _event_subscribers[event_type].is_empty():
		_event_subscribers.erase(event_type)

## 获取事件统计信息（调试用）
## [return] Dictionary 包含事件触发次数统计
func get_event_stats() -> Dictionary:
	var stats: Dictionary = {}
	for event_type in _event_subscribers.keys():
		stats[event_type] = {
			"subscriber_count": _event_subscribers[event_type].size()
		}
	return stats

## 获取事件日志（仅在 enable_debug = true 时有效）
## [param] event_type: StringName 可选，如果提供则只返回该类型的事件
## [return] Array[Dictionary] 事件日志数组
func get_event_log(event_type: StringName = &"") -> Array[Dictionary]:
	if event_type.is_empty():
		return _event_log.duplicate()
	
	var filtered_log: Array[Dictionary] = []
	for entry in _event_log:
		if entry.get("type") == event_type:
			filtered_log.append(entry)
	return filtered_log

## 清空事件日志
func clear_event_log() -> void:
	_event_log.clear()

# ========== 内部方法 ==========

## 记录事件到日志
func _log_event(event_type: StringName, context: Dictionary) -> void:
	var log_entry = {
		"type": event_type,
		"context": context.duplicate(true),
		"time": Time.get_ticks_msec(),
		"frame": Engine.get_process_frames()
	}
	
	_event_log.append(log_entry)
	
	# 限制日志大小
	if _event_log.size() > MAX_LOG_ENTRIES:
		_event_log.pop_front()
	
	# 打印调试信息
	print("[AbilityEventBus] Event: %s (subscribers: %d)" % [
		event_type,
		_event_subscribers.get(event_type, []).size()
	])
