extends CombatEventContext
class_name DamageReceivedContext

## 受到伤害事件上下文

var source: Node
var target: Node
var damage_info: DamageInfo

func _init(p_source: Node, p_target: Node, p_damage_info: DamageInfo) -> void:
	source = p_source
	target = p_target
	damage_info = p_damage_info

func get_event_type() -> StringName:
	return &"damage_received"

func to_dict() -> Dictionary:
	return {
		"source": source,
		"target": target,
		"damage_info": damage_info
	}
