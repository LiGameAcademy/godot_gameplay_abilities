extends GameplayEffect
class_name GE_ApplyDamage

## 应用伤害效果
## 默认会阻挡带有 state.invulnerable 标签的目标（免疫伤害）。
## 如需让某个资源忽略此默认值，可将 add_default_invulnerable_block 设为 false，
## 或直接在资源上自定义 target_blocked_tags。

@export var damage_multiplier: float = 1.0 ## 伤害倍数
@export var vital_id : StringName = &"health"
@export var base_damage_attribute : StringName = &"attack"
@export var vital_comp_name : StringName = &"GameplayAttributeComponent"
@export var instigator_attribute_comp_name : StringName = &"GameplayAttributeComponent"
@export var ability_comp_name : StringName = &"GameplayAbilityComponent"
## 免疫伤害标签
@export var invulnerable_block_tag: StringName = &"state.invulnerable"

func _init() -> void:
	# 为伤害效果提供默认的免疫标签，避免在每个资源里手工配置
	# 可通过将 add_default_invulnerable_block 设为 false 来禁用该默认值
	if target_blocked_tags.is_empty() and not invulnerable_block_tag.is_empty():
		target_blocked_tags = [invulnerable_block_tag]

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
	var base_final_damage = base_damage * damage_multiplier
	
	# 应用 Modifier 提供的伤害倍率（如果存在）
	var modifier_multiplier = context.get("damage_multiplier_modifier", 1.0)
	base_final_damage *= modifier_multiplier
	
	var damage_info = DamageInfo.new(instigator, ability_comp, base_final_damage)
	
	# 应用伤害（HealthVital 内部会计算最终伤害并返回）
	var final_damage = health_vital.apply_damage(damage_info, target)
	
	# 将最终伤害值添加到上下文，供 Cue 使用
	context["final_damage"] = final_damage
	
	AbilityEventBus.trigger_game_event(&"damage_applied", {
		"target": target,
		"instigator": instigator,
		"damage_info": damage_info
	})

func _get_description() -> String:
	return "Apply %s damage to %s\n" % [damage_multiplier, vital_comp_name]
