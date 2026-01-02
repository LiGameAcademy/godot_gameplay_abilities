extends Node

## 技能事件总线（单例）
## 提供全局事件通讯机制，实现组件间的解耦
## 支持统一的事件触发接口的事件信号

# ========== 统一游戏事件系统 ==========
## 统一游戏事件信号
## 所有游戏事件都通过此信号统一触发
## [param] event_type: StringName 事件类型，如 "damage_applied", "vital_modified" 等
## [param] context: Dictionary 事件上下文，包含事件相关的所有信息
signal game_event_occurred(event_type: StringName, context: Dictionary)

## 触发游戏事件（统一接口）
## [param] event_or_type: Variant 事件类型（StringName）
## [param] context: Variant 事件上下文（Dictionary，可选）
func trigger_game_event(event_type: StringName, context: Variant = {}) -> void:
	# 发出统一游戏事件信号
	game_event_occurred.emit(event_type, context)
