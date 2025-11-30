extends ActiveAbility
class_name ToggleAbility

## 切换技能数据
## 可以在开启和关闭状态之间切换的技能

@export_group("Toggle Ability")
@export var toggled_off_icon: Texture2D  ## 关闭状态的图标
@export var toggled_off_status_to_apply: GameplayStatusData = null  ## 关闭状态时应用的状态

var is_toggled_on: bool = false  ## 技能是否处于激活状态

func _can_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> bool:
	# 如果已经开启，可以关闭
	if is_toggled_on:
		return true
	# 否则检查正常施法条件
	return super._can_cast(ability_comp, target, context)

func _commit_cast(ability_comp: Node) -> bool:
	# 如果未开启，需要消耗资源和冷却
	if not is_toggled_on:
		if ability_comp.has_method("try_spend_mana"):
			if not ability_comp.try_spend_mana(mana_cost):
				return false
		
		if ability_comp.has_method("start_cooldown"):
			ability_comp.start_cooldown(ability_id, cooldown_duration)
	
	# 切换状态
	is_toggled_on = not is_toggled_on
	return true

func _on_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> void:
	if not is_instance_valid(ability_comp) or not is_instance_valid(target): 
		return
	
	# 使用鸭子类型查询GameplayStatusComponent
	var target_status_comp = CombatSystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(target_status_comp):
		push_error("ToggleAbility: GameplayStatusComponent not found")
		return
	
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	
	# 根据切换状态应用不同的状态
	if not is_toggled_on:
		# 关闭：移除开启状态，应用关闭状态
		if is_instance_valid(status_to_apply) and target_status_comp.has_method("remove_status"):
			target_status_comp.remove_status(status_to_apply.status_id)
		if is_instance_valid(toggled_off_status_to_apply) and target_status_comp.has_method("apply_status"):
			target_status_comp.apply_status(toggled_off_status_to_apply, instigator)
	else:
		# 开启：应用开启状态
		if is_instance_valid(status_to_apply) and target_status_comp.has_method("apply_status"):
			target_status_comp.apply_status(status_to_apply, instigator)

