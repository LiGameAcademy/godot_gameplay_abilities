extends CombatEvent
class_name DamageReceivedEvent

## 受到伤害事件

## 使用强类型上下文初始化（推荐）
func _init(p_context: DamageReceivedContext) -> void:
	super(p_context.get_event_type(), p_context)

## 使用字典初始化（向后兼容）
static func from_dict(context: Dictionary) -> DamageReceivedEvent:
	return DamageReceivedEvent.new(DamageReceivedContext.new(
		context.get("source"),
		context.get("target"),
		context.get("damage_info")
	))

func emit_gameplay_signal(event_bus: AbilityEventBus) -> void:
	var ctx = get_context()
	if validate_context(["target", "damage_info"]):
		event_bus.damage_received.emit(ctx["target"], ctx["damage_info"])

