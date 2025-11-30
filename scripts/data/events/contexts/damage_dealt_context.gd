extends CombatEventContext
class_name DamageDealtContext

## 造成伤害事件上下文

var instigator: Node
var target: Node
var damage_info: DamageInfo
var final_damage: float

func _init(p_instigator: Node, p_target: Node, p_damage_info: DamageInfo, p_final_damage: float) -> void:
	instigator = p_instigator
	target = p_target
	damage_info = p_damage_info
	final_damage = p_final_damage

func get_event_type() -> StringName:
	return &"damage_dealt"

func to_dict() -> Dictionary:
	return {
		"instigator": instigator,
		"target": target,
		"damage_info": damage_info,
		"final_damage": final_damage
	}
