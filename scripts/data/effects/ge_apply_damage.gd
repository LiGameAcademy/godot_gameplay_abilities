extends GameplayEffect
class_name GE_ApplyDamage

## 应用伤害效果

@export var damage_multiplier: float = 1.0 ## 伤害倍数
@export var vital_id : StringName = &"health"
@export var vital_comp_name : StringName = &"GameplayAttributeComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name)
	if not vital_comp:
		push_error("GE_ApplyDamage: Target %s has no %s component" % [target.name, vital_comp_name])
		return
	
	var health_vital : HealthVital = vital_comp.get_vital(vital_id)
	if not health_vital:
		push_error("GE_ApplyDamage: Target %s has no %s vital" % [target.name, vital_id])
		return

	var damage_info = DamageInfo.new(instigator, null, damage_multiplier, false)
	health_vital.apply_damage(damage_info, target)
	AbilityEventBus.trigger_game_event(&"damage_applied", {
		"target": target,
		"instigator": instigator,
		"damage_info": damage_info
	})

func _get_description() -> String:
	return "Apply %s damage to %s\n" % [damage_multiplier, vital_comp_name]
