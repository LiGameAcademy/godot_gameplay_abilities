@abstract
extends Resource
class_name StatusDurationPolicy

## 持续时间策略基类（抽象类）
## 定义状态持续时间的更新逻辑

## 初始化持续时间
## [param] instance: GameplayStatusInstance 状态实例
## [param] duration: float 持续时间（秒或回合数）
func initialize(instance: GameplayStatusInstance, duration: float) -> void:
	_initialize(instance, duration)
## 更新持续时间
## [param] instance: GameplayStatusInstance 状态实例
## [param] delta: float 帧时间（仅用于自然时间策略）
## [return] bool 是否已过期（需要移除）
func update(instance: GameplayStatusInstance, delta: float) -> bool:
	return _update(instance, delta)
## 刷新持续时间
## [param] instance: GameplayStatusInstance 状态实例
## [param] duration: float 持续时间
func refresh(instance: GameplayStatusInstance, duration: float) -> void:
	_refresh(instance, duration)
## 累加持续时间
## [param] instance: GameplayStatusInstance 状态实例
## [param] duration: float 持续时间
func accumulate(instance: GameplayStatusInstance, duration: float) -> void:
	_accumulate(instance, duration)
## 处理事件
func handle_event(instance: GameplayStatusInstance, event_id : StringName, event_context: Dictionary) -> void:
	_handle_event(instance, event_id, event_context)

## [子类重写] 初始化持续时间的具体实现
@abstract func _initialize(instance: GameplayStatusInstance, duration: float) -> void

## [子类重写] 更新持续时间的具体实现
func _update(instance: GameplayStatusInstance, delta: float) -> bool:
	return false

## [子类重写] 刷新持续时间的具体实现
func _refresh(instance: GameplayStatusInstance, duration: float) -> void:
	pass

## [子类重写] 累加持续时间的具体实现
func _accumulate(instance: GameplayStatusInstance, duration: float) -> void:
	pass

## [子类重写] 处理事件
func _handle_event(instance: GameplayStatusInstance, event_id : StringName, event_context: Dictionary) -> void:
	pass
