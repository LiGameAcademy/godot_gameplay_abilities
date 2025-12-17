extends GameplayEffect
class_name GE_DamageModification

## 伤害修改效果（事件监听型）
## 用于减少或增加目标的伤害

@export var reduction_multiplier: float = 0.6  ## 伤害的减少倍率（<1.0为减少，>1.0为增加）

func _apply(_target: Node, _instigator: Node, context: AbilityContext) -> void:
	# 这个效果需要在伤害事件触发时修改伤害值
	# 通过context中的damage_info来修改
	var damage_info: DamageInfo = context.damage_info
	if not is_instance_valid(damage_info): 
		return
	
	# 修改伤害值
	damage_info.base_damage *= reduction_multiplier
	
	# 如果context中有stacks信息，应用层数
	var stacks = context.custom_data.get("stacks", 1)
	if stacks > 1:
		damage_info.base_damage *= stacks
	
func _get_description() -> String:
	if reduction_multiplier < 1.0:
		return "Damage reduced by %s%%\n" % [(1.0 - reduction_multiplier) * 100]
	else:
		return "Damage increased by %s%%\n" % [(reduction_multiplier - 1.0) * 100]

