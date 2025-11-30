extends CombatEvent
class_name DamageDealtEvent

## 造成伤害事件

## 使用强类型上下文初始化（推荐）
func _init(p_context: DamageDealtContext) -> void:
	super(p_context.get_event_type(), p_context)

## 使用字典初始化（向后兼容）
static func from_dict(context: Dictionary) -> DamageDealtEvent:
	return DamageDealtEvent.new(DamageDealtContext.new(
		context.get("instigator"),
		context.get("target"),
		context.get("damage_info"),
		context.get("final_damage", 0.0)
	))

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
	var ctx = get_context()
	if validate_context(["instigator", "target", "damage_info", "final_damage"]):
		event_bus.damage_dealt.emit(
			ctx["instigator"], 
			ctx["target"], 
			ctx["damage_info"], 
			ctx["final_damage"]
		)

