extends StatusFeature
class_name FeaturePeriodicEffects

## 周期性效果特性
## 在指定周期触发效果

@export var period: float = 1.0  # 周期时间（秒）
@export var periodic_effects: Array[GameplayEffect] = []

func _apply_feature(instance: GameplayStatusInstance, context: Dictionary) -> void:
	_set_timer(instance, 0.0)

func _update_feature(instance: GameplayStatusInstance, delta: float) -> void:
	if period <= 0.0 or periodic_effects.is_empty():
		return

	var timer = _get_timer(instance) + delta
	_set_timer(instance, timer)

	if timer >= period:
		_set_timer(instance, timer - period)
		# 触发周期性效果
		instance.apply_effects(periodic_effects)

## 获取计时器（从实例中读取）
func _get_timer(instance: GameplayStatusInstance) -> float:
	var feature_storage = instance.get_feature_storage(self)
	return feature_storage.get("timer", 0.0)

## 设置计时器（存储到实例中）
func _set_timer(instance: GameplayStatusInstance, value: float) -> void:
	var feature_storage = instance.get_feature_storage(self)
	feature_storage["timer"] = value
