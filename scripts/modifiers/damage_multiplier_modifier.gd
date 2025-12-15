extends GameplayAbilityModifier
class_name DamageMultiplierModifier

## 伤害倍率修改器
## 效果：为指定技能增加伤害倍率（乘法叠加）
##
## 使用场景：
## - 天赋："伤害强化"（所有技能伤害 +50%）
## - 装备词条："暴击强化"（暴击技能伤害 +100%）
## - 状态："狂暴"（所有技能伤害 +200%）

## 伤害倍率（乘法叠加）
## 例如：1.5 表示伤害增加 50%，2.0 表示伤害翻倍
## 多个修改器会累乘：1.5 * 2.0 = 3.0（最终伤害为 300%）
@export_range(0.0, 10.0, 0.01) var damage_multiplier: float = 1.5

## 钩子：效果应用时（拦截伤害效果并修改倍率）
func on_effect_applied(
	effect: GameplayEffect,
	target: Node,
	instigator: Node,
	context: Dictionary
) -> void:
	# 只影响伤害效果
	if not effect is GE_ApplyDamage:
		return
	
	# 检查是否影响此技能
	# 优先从 context 获取 ability 实例（在 on_before_apply_ability 中设置）
	var ability = context.get("ability", null)
	var ability_comp = context.get("ability_comp", null)
	
	if is_instance_valid(ability):
		# 有 ability 实例，使用完整的检查逻辑
		if not affects_ability(ability, ability_comp):
			return
	elif not affected_ability_ids.is_empty():
		# 没有 ability 实例，至少检查 ability_id
		var ability_id = context.get("ability_id", &"")
		if ability_id.is_empty() or ability_id not in affected_ability_ids:
			return
	else:
		# 没有过滤条件，影响所有技能（通用修改器）
		pass
	
	# 修改伤害倍率（累乘）
	var current_multiplier = context.get("damage_multiplier_modifier", 1.0)
	context["damage_multiplier_modifier"] = current_multiplier * damage_multiplier
	
	print("DamageMultiplierModifier: Applied %.2fx damage multiplier (total: %.2fx)" % [
		damage_multiplier,
		context.get("damage_multiplier_modifier", 1.0)
	])

