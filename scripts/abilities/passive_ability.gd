extends GameplayAbility
class_name PassiveAbility

## 被动技能
## 特性：
## - 不参与施放流程（不消耗、不冷却、不需要目标）
## - 在学习技能时应用配置的状态列表
## - 在遗忘技能时移除对应状态

@export_group("Passive Settings")
## 被动技能是否可以在 UI 中显示（例如天赋树），默认 true
@export var visible_in_ui: bool = true

func _on_cast(_ability_comp: Node, _target: Node, _context: AbilityContext) -> void:
	# 被动技能不支持主动施放
	pass

func _can_cast(_ability_comp: Node, _target: Node, _context: AbilityContext) -> bool:
	# 被动技能永远不可施放
	return false

func _commit_cast(_ability_comp: Node, _context: AbilityContext) -> bool:
	# 被动技能没有消耗与冷却逻辑
	return false

func get_cast_point() -> float:
	return 0.0

func get_cooldown_duration() -> float:
	return 0.0

func get_animation_name() -> StringName:
	return &""

## 学习被动技能时：为拥有者应用状态
func _on_learned(ability_comp: Node, status_comp: Node) -> void:
	if not is_instance_valid(status_comp) or statuses.is_empty():
		return
	
	# 施加者 = 技能组件所在实体
	var instigator: Node = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		return
	
	# 使用基类方法应用状态（被动技能默认应用到拥有者自己，不需要 targeting_strategy）
	var context = AbilityContext.create()
	context.instigator = instigator
	context.input_target = instigator
	_apply_statuses_to_targets(instigator, instigator, context, null)

## 遗忘被动技能时：移除对应状态
func _on_forgotten(_ability_comp: Node, status_comp: Node) -> void:
	if not is_instance_valid(status_comp):
		return
	
	# 获取实体（技能组件所在实体）
	var entity: Node = _ability_comp.get_parent()
	if not is_instance_valid(entity):
		return
	
	# 使用基类方法移除状态
	_remove_all_statuses_from_entity(entity, status_comp)


