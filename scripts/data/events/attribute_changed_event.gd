extends CombatEvent
class_name AttributeChangedEvent

## 属性变化事件

func _init(p_context: Dictionary) -> void:
	super(&"attribute_changed", p_context)

func emit_gameplay_signal(event_bus: AbilityEventBus) -> void:
	if validate_context(["entity", "attribute_id", "new_value"]):
		event_bus.attribute_changed.emit(
			context["entity"], 
			context["attribute_id"], 
			context["new_value"]
		)

