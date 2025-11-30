extends CombatEvent
class_name StatusAppliedEvent

## 状态应用事件

func _init(p_context: Dictionary) -> void:
	super(&"status_applied", p_context)

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
	if validate_context(["entity", "status_id"]):
		event_bus.status_applied.emit(context["entity"], context["status_id"])

