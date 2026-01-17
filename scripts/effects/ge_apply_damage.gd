extends GameplayEffect
class_name GE_ApplyDamage

## 应用伤害效果
## 默认会阻挡带有 state.invulnerable 标签的目标（免疫伤害）

@export var damage_multiplier: float = 1.0  ## 伤害倍数
@export var invulnerable_block_tag: StringName = &"state.invulnerable"  ## 免疫伤害标签
@export var damage_strategy : DamageLogicStrategy = SimpleDamageLogic.new()
@export var vital_comp_name : StringName = &"GameplayVitalAttributeComponent"
@export var vital_id : StringName = &"health"
@export var base_damage_attribute : StringName = &""  ## 基础伤害属性（如果为空，从 context 获取 base_damage）

func _init() -> void:
	# 为伤害效果提供默认的免疫标签，避免在每个资源里手工配置
	if target_blocked_tags.is_empty() and not invulnerable_block_tag.is_empty():
		target_blocked_tags = [invulnerable_block_tag]

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	# 1. 获取组件
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name)
	if not vital_comp:
		push_error("GE_ApplyDamage: Target %s has no %s component" % [target.name, vital_comp_name])
		return
	
	var health_vital: HealthVital = vital_comp.get_vital(vital_id)
	if not health_vital:
		push_error("GE_ApplyDamage: Target %s has no %s vital" % [target.name, vital_id])
		return
	
	# 2. 获取基础伤害
	var base_damage: float = 0.0
	if not base_damage_attribute.is_empty() and is_instance_valid(instigator):
		# 从攻击者属性中获取基础伤害
		var instigator_attr_comp = GameplayAbilitySystem.get_component_by_interface(instigator, &"GameplayAttributeComponent")
		if instigator_attr_comp:
			base_damage = instigator_attr_comp.get_value(base_damage_attribute, 0.0)
		else:
			push_warning("GE_ApplyDamage: Instigator %s has no GameplayAttributeComponent" % instigator.name)
	else:
		# 从 context 中获取基础伤害
		base_damage = context.get("base_damage", 0.0)
	
	if base_damage <= 0.0:
		push_warning("GE_ApplyDamage: base_damage is 0 or negative, skipping damage application")
		return
	
	# 3. 更新 context 中的伤害倍率
	damage_multiplier = context.get("damage_multiplier", damage_multiplier)
	context["damage_multiplier"] = damage_multiplier
	
	# 4. 获取 stacks 并创建 DamageInfo
	var stacks = context.get("stacks", 1)
	var damage_info = DamageInfo.new(instigator, context.get("source_node", null), base_damage * stacks)
	
	# 5. 计算最终伤害（使用策略）
	var strategy = context.get("damage_strategy", damage_strategy)
	if not is_instance_valid(strategy):
		push_error("GE_ApplyDamage: damage_strategy is not valid")
		return
	
	damage_info.final_damage = strategy.calculate(damage_info, target, instigator, context)
	
	# 6. 应用伤害（由 HealthVital 负责）
	var applied_damage = health_vital.apply_damage(damage_info, target)
	
	# 7. 保存到上下文
	context["final_damage"] = applied_damage
