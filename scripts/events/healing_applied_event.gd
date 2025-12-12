extends CombatEvent
class_name HealingAppliedEvent

## 受到治疗事件

func _init(p_context: Dictionary) -> void:
	super(&"healing_applied", p_context)

func emit_gameplay_signal(event_bus: AbilityEventBus) -> void:
	if validate_context(["target", "amount"]):
		event_bus.healing_applied.emit(context["target"], context["amount"])

