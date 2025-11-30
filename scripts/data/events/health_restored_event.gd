extends CombatEvent
class_name HealthRestoredEvent

## 生命值恢复事件

func _init(p_context: Dictionary) -> void:
	super(&"health_restored", p_context)

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
	if validate_context(["entity"]):
		event_bus.health_restored.emit(context["entity"])

