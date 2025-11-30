@abstract
extends RefCounted
class_name CombatEventContext

## 战斗事件上下文基类
## 所有具体事件上下文都应继承此类，提供类型安全

## 获取事件类型（子类必须实现）
@abstract func get_event_type() -> StringName

## 转换为字典（用于统一事件系统）
@abstract func to_dict() -> Dictionary
