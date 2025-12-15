extends GameplayAbilityModifier
class_name EffectAppenderModifier

## 效果追加修改器
## 效果：为指定技能追加额外的效果
##
## 使用场景：
## - 天赋："元素附魔"（所有技能追加火焰伤害）
## - 装备词条："生命汲取"（所有伤害技能追加治疗效果）
## - 状态："毒素武器"（所有近战技能追加中毒效果）

## 要追加的效果列表
@export var additional_effects: Array[GameplayEffect] = []

## 是否追加到所有目标（如果为 false，只追加到 input_target）
@export var apply_to_all_targets: bool = true

## 钩子：技能真正生效前（追加效果）
func on_before_apply_ability(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	target: Node,
	context: Dictionary
) -> void:
	# 检查是否影响此技能
	if not affects_ability(ability, ability_comp):
		return
	
	if additional_effects.is_empty():
		return
	
	# 获取要追加的效果列表（如果 context 中已有，则追加；否则创建新列表）
	var extra_effects = context.get("extra_effects", [])
	if not extra_effects is Array:
		extra_effects = []
	
	# 追加所有配置的效果
	for effect in additional_effects:
		if is_instance_valid(effect):
			extra_effects.append(effect)
	
	context["extra_effects"] = extra_effects
	context["apply_extra_effects_to_all_targets"] = apply_to_all_targets
	
	print("EffectAppenderModifier: Added %d extra effects to ability %s" % [
		additional_effects.size(),
		ability.ability_id
	])

