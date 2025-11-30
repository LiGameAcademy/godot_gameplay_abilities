extends CombatEvent
class_name AbilityFailedEvent

## 技能失败事件

func _init(p_context: Dictionary) -> void:
	super(&"ability_failed", p_context)

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
	if validate_context(["entity", "ability_id", "reason"]):
		event_bus.ability_failed.emit(
			context["entity"], 
			context["ability_id"], 
			context["reason"]
		)

