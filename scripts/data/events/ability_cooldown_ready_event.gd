extends CombatEvent
class_name AbilityCooldownReadyEvent

## 技能冷却就绪事件

func _init(p_context: Dictionary) -> void:
	super(&"ability_cooldown_ready", p_context)

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
	if validate_context(["entity", "ability_id"]):
		event_bus.ability_cooldown_ready.emit(context["entity"], context["ability_id"])

