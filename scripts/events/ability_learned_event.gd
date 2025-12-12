extends CombatEvent
class_name AbilityLearnedEvent

## 技能学习事件

func _init(p_context: Dictionary) -> void:
	super(&"ability_learned", p_context)

func emit_gameplay_signal(event_bus: AbilityEventBus) -> void:
	if validate_context(["entity", "ability_id"]):
		event_bus.ability_learned.emit(context["entity"], context["ability_id"])

