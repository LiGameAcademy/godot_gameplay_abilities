extends StatusFeature
class_name FeatureEventListener

## 事件监听特性
## 监听指定事件并触发效果

@export var trigger_on_events: Array[StringName] = []
@export var event_triggered_effects: Array[GameplayEffect] = []

## 检查此状态是否可以被指定事件触发
func can_trigger_on_event(event_type: StringName) -> bool:
	return trigger_on_events.has(event_type)

func has_event_listening() -> bool:
	return not trigger_on_events.is_empty()

func _handle_event(instance: GameplayStatusInstance, event_id: StringName, context: Dictionary) -> void:
	if not trigger_on_events.has(event_id):
		return

	# 触发事件效果
	instance.apply_effects(event_triggered_effects, context)
