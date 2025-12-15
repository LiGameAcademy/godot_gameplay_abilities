extends Resource
class_name GameplayAbilityModifier

## 技能行为修改器
## 用于在不修改核心技能代码的情况下，通过钩子机制改变技能行为
## 支持：修改参数、追加效果、拦截流程等
##
## 与 GameplayAttributeModifier 的区别：
## - AttributeModifier：只修改数值（攻击力、防御力等）
## - GameplayAbilityModifier：修改逻辑（技能行为、效果流程等）

## 适用范围过滤（可选）
## 如果设置了，只对匹配的技能生效
@export var affected_ability_tags: Array[StringName] = []
@export var affected_ability_ids: Array[StringName] = []

## 来源标识（用于追踪和清理）
## 例如："equipment.sword_of_fire", "talent.arcane_mastery", "status.rage"
var source: String = ""

## 检查是否影响指定技能
## [param] ability: GameplayAbility 技能实例
## [param] ability_comp: GameplayAbilityComponent 技能组件（可选，用于 Tag 检查）
## [return] bool 是否影响此技能
func affects_ability(ability: GameplayAbility, ability_comp: GameplayAbilityComponent = null) -> bool:
	if not is_instance_valid(ability):
		return false
	
	# 如果未设置过滤条件，默认影响所有技能
	if affected_ability_ids.is_empty() and affected_ability_tags.is_empty():
		return true
	
	# 检查 ID 匹配
	if not affected_ability_ids.is_empty():
		if ability.ability_id in affected_ability_ids:
			return true
	
	# 检查 Tag 匹配（需要查询 TagManager）
	if not affected_ability_tags.is_empty():
		var ability_entity = null
		# 优先从 ability_comp 获取实体
		if is_instance_valid(ability_comp):
			ability_entity = ability_comp.get_parent()
		# 回退：尝试从 ability 获取实体（通常需要通过 ability_comp）
		elif ability.has_method("get_instigator"):
			ability_entity = ability.call("get_instigator")
		
		if is_instance_valid(ability_entity):
			return TagManager.has_any_tag(ability_entity, affected_ability_tags)
	
	return false

## 钩子：施法前（还未扣资源、未进冷却）
## 可以修改 context，影响后续流程
## [param] ability_comp: GameplayAbilityComponent 技能组件
## [param] ability: GameplayAbility 技能实例
## [param] context: Dictionary 上下文（可修改）
func on_before_ability_cast(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	context: Dictionary
) -> void:
	pass

## 钩子：施法成功后（已经 commit 成功，准备进入前摇/释放）
## 可以追加效果、修改参数等
## [param] ability_comp: GameplayAbilityComponent 技能组件
## [param] ability: GameplayAbility 技能实例
## [param] context: Dictionary 上下文（可修改）
func on_after_ability_commit(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	context: Dictionary
) -> void:
	pass

## 钩子：技能真正生效时（_on_cast 要执行前）
## 这是修改技能参数的最佳时机（如投射物数量、伤害倍率等）
## [param] ability_comp: GameplayAbilityComponent 技能组件
## [param] ability: GameplayAbility 技能实例
## [param] target: Node 目标
## [param] context: Dictionary 上下文（可修改）
func on_before_apply_ability(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	target: Node,
	context: Dictionary
) -> void:
	pass

## 钩子：效果应用时（可拦截并追加其它效果）
## 注意：这是同步调用，会阻塞当前流程，适合"修改"而非"触发新流程"
## [param] effect: GameplayEffect 效果实例
## [param] target: Node 目标
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文（可修改）
func on_effect_applied(
	effect: GameplayEffect,
	target: Node,
	instigator: Node,
	context: Dictionary
) -> void:
	pass

