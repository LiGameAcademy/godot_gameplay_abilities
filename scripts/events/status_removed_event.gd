extends CombatEvent
class_name StatusRemovedEvent

## 状态移除事件

func _init(p_context: Dictionary) -> void:
	super(&"status_removed", p_context)

func emit_gameplay_signal(event_bus: AbilityEventBus) -> void:
	if validate_context(["entity", "status_id"]):
		event_bus.status_removed.emit(context["entity"], context["status_id"])

