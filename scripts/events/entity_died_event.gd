extends CombatEvent
class_name EntityDiedEvent

## 实体死亡事件

func _init(p_context: Dictionary) -> void:
	super(&"entity_died", p_context)

func emit_gameplay_signal(event_bus: AbilityEventBus) -> void:
	if validate_context(["entity", "instigator"]):
		event_bus.entity_died.emit(context["entity"], context["instigator"])

