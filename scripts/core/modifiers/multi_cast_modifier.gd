extends GameplayAbilityModifier
class_name MultiCastModifier

## 多重施法修改器
## 效果：为指定技能增加额外的投射物数量
##
## 使用场景：
## - 天赋："多重施法"（火球术 +2 投射物）
## - 装备词条："奥术强化"（所有奥术技能 +1 投射物）
## - 状态："法术连击"（下一个技能 +3 投射物）

## 额外投射物数量
@export var extra_projectiles: int = 1

## 是否只影响投射物技能（ProjectileAbility）
## 如果为 true，只对 ProjectileAbility 生效
@export var only_projectile_abilities: bool = true

## 钩子：技能真正生效前（修改投射物数量）
func on_before_apply_ability(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	target: Node,
	context: Dictionary
) -> void:
	# 检查是否影响此技能
	if not affects_ability(ability, ability_comp):
		return
	
	# 如果设置了只影响投射物技能，检查类型
	if only_projectile_abilities:
		if not ability is ProjectileAbility:
			return
	
	# 修改 context，增加额外投射物数量
	var current_extra = context.get("extra_projectiles", 0)
	context["extra_projectiles"] = current_extra + extra_projectiles
	
	print("MultiCastModifier: Added %d extra projectiles to ability %s (total: %d)" % [
		extra_projectiles,
		ability.ability_id,
		context.get("extra_projectiles", 0)
	])

