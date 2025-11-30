extends CombatEvent
class_name AbilityForgottenEvent

## 技能遗忘事件

func _init(p_context: Dictionary) -> void:
	super(&"ability_forgotten", p_context)

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
	if validate_context(["entity", "ability_id"]):
		event_bus.ability_forgotten.emit(context["entity"], context["ability_id"])
