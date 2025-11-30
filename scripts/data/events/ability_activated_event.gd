extends CombatEvent
class_name AbilityActivatedEvent

## 技能激活事件

func _init(p_context: Dictionary) -> void:
	super(&"ability_activated", p_context)

func emit_gameplay_signal(event_bus: AbilityEventBus) -> void:
	if validate_context(["entity", "ability_id"]):
		event_bus.ability_activated.emit(context["entity"], context["ability_id"])

