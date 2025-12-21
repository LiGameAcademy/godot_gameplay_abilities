extends GameplayAbilityFeature
class_name PassiveFeature

## 被动技能特性
## 提供被动技能的生命周期管理（学习时应用状态、遗忘时移除状态）
## 
## 使用方式：
## ```gdscript
## var ability = GameplayAbility.new()
## ability.statuses = [status_data]  # 配置要应用的状态
## ability.features = [PassiveFeature.new()]
## ```

@export_group("Passive Settings")
## 被动技能是否可以在 UI 中显示（例如天赋树），默认 true
@export var visible_in_ui: bool = true
## 学习技能时应用，遗忘技能时移除
@export var execution_statuses : Array[GameplayStatusData]

func _init() -> void:
	super("PassiveFeature")

func on_learned(ability: GameplayAbilityInstance, ability_comp: Node, status_comp: Node) -> void:
	# 应用状态（如果配置了）
	if not is_instance_valid(status_comp):
		return
	
	# 施加者 = 技能组件所在实体
	var instigator: Node = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		return
	
	# 使用基类方法应用状态（被动技能默认应用到拥有者自己，不需要 targeting_strategy）
	var context = AbilityContext.create()
	context.instigator = instigator
	context.input_target = instigator

	for status_data in execution_statuses:
		status_comp.apply_status(status_data, instigator, 1, context)

func on_forgotten(ability: GameplayAbilityInstance, ability_comp: Node, status_comp: Node) -> void:
	if not is_instance_valid(status_comp):
		return
	
	# 获取实体（技能组件所在实体）
	var entity: Node = ability_comp.get_parent()
	if not is_instance_valid(entity):
		return
	
	# 使用基类方法移除状态
	for status_data in execution_statuses:
		if not is_instance_valid(status_data):
			continue
		var sid: StringName = status_data.status_id
		if not sid.is_empty():
			status_comp.remove_status(sid)

func get_description() -> String:
	return "被动技能：学习时自动应用状态，遗忘时自动移除"
