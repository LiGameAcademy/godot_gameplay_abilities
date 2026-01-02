extends GameplayEffect
class_name GE_ModifyIncomingDamage

## 修改即将到来的伤害（在 HealthVital.apply_damage 中触发之前）
## 典型用法：
## - 减伤护盾：将伤害乘以 0.5
## - 易伤：将伤害乘以 1.5
## 要求：
## - 该 Effect 应该挂在监听 damage_received 事件的状态上

@export_range(0.0, 10.0, 0.01) var damage_multiplier: float = 0.5

func _apply(target: Node, _instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(context.damage_info):
		return
	
	var damage_info: DamageInfo = context.damage_info
	if not is_instance_valid(damage_info):
		push_error("GE_ModifyIncomingDamage: damage_info is invalid")
		return
	
	damage_info.final_damage *= damage_multiplier

func _get_description() -> String:
	return "Modify incoming damage by multiplier %.2f\n" % damage_multiplier
