extends GameplayAbilityModifier
class_name CooldownReductionModifier

## 冷却缩减修改器
## 效果：减少指定技能的冷却时间（百分比缩减）
##
## 使用场景：
## - 天赋："急速冷却"（所有技能冷却 -20%）
## - 装备词条："战斗专注"（近战技能冷却 -30%）
## - 状态："时间加速"（所有技能冷却 -50%）

## 冷却缩减百分比（0.0-1.0）
## 例如：0.2 表示冷却时间减少 20%，0.5 表示冷却时间减少 50%
## 多个修改器会累加（但不超过 100%）：0.2 + 0.3 = 0.5（最终冷却为 50%）
@export_range(0.0, 1.0, 0.01) var cooldown_reduction: float = 0.2

## 钩子：施法成功后（修改冷却时间）
func on_after_ability_commit(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	context: Dictionary
) -> void:
	# 检查是否影响此技能
	if not affects_ability(ability, ability_comp):
		return
	
	# 累加冷却缩减（多个修改器会累加）
	var current_reduction = context.get("cooldown_reduction", 0.0)
	context["cooldown_reduction"] = min(1.0, current_reduction + cooldown_reduction)
	
	print("CooldownReductionModifier: Applied %.0f%% cooldown reduction (total: %.0f%%)" % [
		cooldown_reduction * 100.0,
		context.get("cooldown_reduction", 0.0) * 100.0
	])

