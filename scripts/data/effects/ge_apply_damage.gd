extends GameplayEffect
class_name GE_ApplyDamage

## 应用伤害效果

@export var damage_multiplier: float = 1.0 ## 伤害倍数
@export var vital_id : StringName = &"health"
@export var base_damage_attribute : StringName = &"attack"
@export var vital_comp_name : StringName = &"GameplayAttributeComponent"
@export var instigator_attribute_comp_name : StringName = &"GameplayAttributeComponent"
@export var ability_comp_name : StringName = &"GameplayAbilityComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name)
	if not vital_comp:
		push_error("GE_ApplyDamage: Target %s has no %s component" % [target.name, vital_comp_name])
		return
	
	var health_vital : HealthVital = vital_comp.get_vital(vital_id)
	if not health_vital:
		push_error("GE_ApplyDamage: Target %s has no %s vital" % [target.name, vital_id])
		return

	var attribute_comp : GameplayAttributeComponent = GameplayAbilitySystem.get_component_by_interface(instigator, instigator_attribute_comp_name)
	if not attribute_comp:
		push_error("GE_ApplyDamage: Instigator %s has no %s component" % [instigator.name, instigator_attribute_comp_name])
		return

	var ability_comp : GameplayAbilityComponent = GameplayAbilitySystem.get_component_by_interface(instigator, ability_comp_name)
	if not ability_comp:
		push_error("GE_ApplyDamage: Instigator %s has no %s component" % [instigator.name, ability_comp_name])
		return

	var base_damage = attribute_comp.get_value(base_damage_attribute)
	var final_damage = base_damage * damage_multiplier
	var damage_info = DamageInfo.new(instigator, ability_comp, final_damage)
	health_vital.apply_damage(damage_info, target)
	AbilityEventBus.trigger_game_event(&"damage_applied", {
		"target": target,
		"instigator": instigator,
		"damage_info": damage_info
	})

func _get_description() -> String:
	return "Apply %s damage to %s\n" % [damage_multiplier, vital_comp_name]
