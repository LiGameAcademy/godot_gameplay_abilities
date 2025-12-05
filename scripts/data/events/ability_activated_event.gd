extends CombatEvent
class_name AbilityCompletedEvent

## 技能完成事件（所有逻辑执行完毕）

func _init(p_context: Dictionary) -> void:
	super(&"ability_completed", p_context)

func emit_gameplay_signal(event_bus: AbilityEventBus) -> void:
	if validate_context(["entity", "ability_id"]):
		event_bus.ability_completed.emit(context["entity"], context["ability_id"])

