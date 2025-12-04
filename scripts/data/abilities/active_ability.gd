extends GameplayAbility
class_name ActiveAbility

## 主动技能数据

@export_group("Casting Rules")
@export var targeting_type: TargetingType = TargetingType.UNIT_TARGET  ## 目标类型
@export var cooldown_duration: float = 0.0  ## 技能冷却时间
@export var costs: Array[AbilityCostBase] = []  ## 技能消耗器数组（支持多种消耗类型）
@export var cast_duration: float = 1.0  ## 施法/引导的总时长
@export var cast_point: float = 0.5  ## 施法前摇时间 (动画关键帧)
@export var cast_range: float = 8.0  ## 施法距离
@export var channel_duration: float = 0.0  ## 引导持续时间
@export var autocast: bool = false  ## 技能是否可以自动施法
@export var animation_name: StringName = &"cast_spell_default"  ## 动画名称
@export var target_filters: Array[GameplayFilterData] = []  ## 技能目标过滤器
@export var indicator_data: TargetIndicatorData = null  ## 目标指示器数据

@export_group("Hit Detection")
## 命中检测器（用于动画关键帧触发时的目标检测）
## 如果设置了此检测器，能力系统会在动画关键帧时主动调用它来获取目标
## 适用于：普通攻击、需要精确时机检测的技能
@export var hit_detector: HitDetectorBase = null

var _is_autocast: bool = false  ## 技能是否自动施法

func can_autocast() -> bool:
	return autocast

func is_autocast() -> bool:
	return _is_autocast

func toggle_autocast() -> void:
	_is_autocast = not _is_autocast

func get_cast_duration() -> float:
	return cast_duration

func get_cast_point() -> float:
	return cast_point

func get_cast_range() -> float:
	return cast_range

func get_channel_duration() -> float:
	return channel_duration

func get_cooldown_duration() -> float:
	return cooldown_duration

func get_animation_name() -> StringName:
	return animation_name

## 获取消耗描述（用于UI显示）
## [return] String 消耗描述文本
func get_costs_description() -> String:
	if costs.is_empty():
		return ""
	
	var cost_descriptions: Array[String] = []
	for cost in costs:
		if is_instance_valid(cost):
			cost_descriptions.append(cost.get_cost_description())
	
	return "\n".join(cost_descriptions)

func _on_learned(_ability_comp: Node, _status_comp: Node) -> void:
	pass

func _on_forgotten(_ability_comp: Node, _status_comp: Node) -> void:
	pass

## 检查是否可以施法
func _can_cast(ability_comp: Node, target: Node = null, context: Dictionary = {}) -> bool:
	if not is_instance_valid(ability_comp): 
		push_error("ActiveAbility: Ability %s can not cast." % ability_id)
		return false
	
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if not is_instance_valid(instigator):
		return false
	
	# 检查是否可以支付所有消耗
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		if not cost.can_pay(ability_comp, instigator):
			return false
	
	#TODO 开始冷却
	#TODO 检查目标过滤器

	return true

func _commit_cast(ability_comp: Node) -> bool:
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if not is_instance_valid(instigator):
		push_warning("ActiveAbility: Cannot get instigator for ability %s" % ability_id)
		return false
	
	# 遍历所有消耗器，检查并消耗资源
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		
		# 检查是否可以支付
		if not cost.can_pay(ability_comp, instigator):
			push_warning("ActiveAbility: Cannot pay cost for ability %s: %s" % [ability_id, cost.get_cost_description()])
			return false
		
		# 尝试支付消耗
		if not cost.try_pay(ability_comp, instigator):
			push_warning("ActiveAbility: Failed to pay cost for ability %s: %s" % [ability_id, cost.get_cost_description()])
			return false
	
	return true

func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ActiveAbility: Cannot cast, instigator is not valid")
		return
	
	# 1. 定义最终受击目标列表
	var final_targets: Array[Node] = []
	
	# 2. 如果有检测器（普攻/AOE），优先使用检测器结果
	if hit_detector:
		final_targets = hit_detector.get_targets(instigator, context)

	# 3. 如果没有检测器，但有指定目标（指向性技能），则使用指定目标
	elif is_instance_valid(input_target):
		final_targets.append(input_target)
	
	# 4. 如果没有目标，且技能类型是 SELF_ONLY 或 NO_TARGET，则对施法者自己应用效果
	# 适用于：冲刺、治疗自己、增益技能等
	if final_targets.is_empty():
		if targeting_type == TargetingType.SELF_ONLY or targeting_type == TargetingType.NO_TARGET:
			final_targets.append(instigator)
		
	# 5. 遍历所有目标应用效果
	for target in final_targets:
		if not is_instance_valid(target): 
			continue
		
		# 可以在这里做阵营筛选 (Team Check)
		# if not is_enemy(instigator, target): continue
		
		for effect in effects:
			if is_instance_valid(effect):
				# 对目标应用效果（可能是受害者，也可能是施法者自己）
				effect.apply(target, instigator, context)

func _clear_cast(_ability_comp: Node, target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	var instigator = _ability_comp.get_parent() if _ability_comp.has_method("get_parent") else null
	
	# 1. 移除直接应用的效果（如果有需要移除的效果）
	for effect in effects:
		if is_instance_valid(effect):
			effect.remove(target, instigator)
	
	# 2. 移除状态（可选，向后兼容）
	if is_instance_valid(status_to_apply):
		var target_status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if is_instance_valid(target_status_comp) and target_status_comp.has_method("remove_status"):
			target_status_comp.remove_status(status_to_apply.status_id)

func _play_animation(owner_entity: Node) -> void:
	# 动画播放由业务层实现，这里只提供接口
	# 业务层可以监听技能事件来播放动画
	if not is_instance_valid(owner_entity): 
		return
	
	# 发送技能施放事件
	AbilityEventBus.emit_ability_activated(owner_entity, ability_id)
