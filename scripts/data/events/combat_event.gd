@abstract
extends RefCounted
class_name CombatEvent

## 战斗事件基类（抽象类）
## 所有具体事件类都应继承此类，实现emit_signal方法
## 支持两种初始化方式：
## 1. 传入强类型上下文（推荐，类型安全）
## 2. 传入字典上下文（向后兼容）

## 事件类型
var event_type: StringName
## 事件上下文（可以是CombatEventContext或Dictionary）
var context: Variant

func _init(p_event_type: StringName = &"", p_context: Variant = {}) -> void:
	event_type = p_event_type
	context = p_context
	
	# 如果传入的是CombatEventContext，自动获取事件类型
	if context is CombatEventContext:
		if event_type.is_empty():
			event_type = context.get_event_type()

## 获取事件类型
func get_event_type() -> StringName:
	return event_type

## 获取事件上下文（字典形式）
func get_context() -> Dictionary:
	if context is CombatEventContext:
		return context.to_dict()
	elif context is Dictionary:
		return context
	else:
		return {}

## 验证上下文是否包含必需的字段
## [param] required_keys: Array[String] 必需的键
## [return] bool 是否包含所有必需的键
func validate_context(required_keys: Array[String]) -> bool:
	var context_dict = get_context()
	for key in required_keys:
		if not context_dict.has(key):
			return false
	return true

## 发出细粒度信号（子类必须实现）
## [param] event_bus: CombatEventBus 事件总线实例
@abstract func emit_gameplay_signal(_event_bus: CombatEventBus) -> void
