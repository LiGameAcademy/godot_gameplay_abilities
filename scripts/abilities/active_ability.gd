extends GameplayAbility
class_name ActiveAbility

## 主动技能数据 (v2.0 Refactored)
## 核心改进：分离了"对己效果"和"对敌效果"，解耦了目标获取逻辑

@export_group("Casting Rules")
@export var cooldown_duration: float = 0.0  ## 技能冷却时间
@export var costs: Array[AbilityCostBase] = []  ## 技能消耗器数组（支持多种消耗类型）
@export var cast_point: float = 0.5  ## 施法前摇时间 (动画关键帧)
## 技能执行时间（秒）
## 如果 > 0，技能会在执行时间结束后自动完成
## 如果 <= 0，则使用 cast_point 作为执行时间
## 最终执行时间 = max(execution_duration, cast_point)
@export var execution_duration: float = 0.0
# @export var cast_range: float = 8.0  ## 施法距离
## 命中检测器（用于动画关键帧触发时的目标检测）
## 如果设置了此检测器，能力系统会在动画关键帧时主动调用它来获取目标
## 适用于：普通攻击、需要精确时机检测的技能
@export var hit_detector: HitDetectorBase = null
## [推荐] 目标获取策略（优先使用，提供最大灵活性）
## 如果设置了此策略，将使用策略来获取目标，忽略 targeting_type
@export var targeting_strategy: TargetingStrategy = null

@export var animation_name: StringName = &"cast_spell_default"  ## 动画名称
@export var indicator_data: TargetIndicatorData = null  ## 目标指示器数据

@export_group("Tag Requirements")
## 施法者必须拥有的标签（技能施放的前置条件）
## 如果施法者没有所有必需的标签，技能无法施放
@export var caster_required_tags: Array[StringName] = []
## 施法者不能拥有的标签（技能施放的阻止条件）
## 如果施法者拥有任意一个阻止标签，技能无法施放
@export var caster_blocked_tags: Array[StringName] = []

func get_cast_point() -> float:
	return cast_point

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

## [重写] 获取效果描述
func get_effects_description() -> String:
	var descriptions: Array[String] = []
	
	# 新架构：状态效果
	if not statuses.is_empty():
		descriptions.append("[状态]")
		for status_data in statuses:
			if is_instance_valid(status_data):
				descriptions.append("- %s" % status_data.status_display_name)
				descriptions.append("  %s" % status_data.get_effects_description())
	return "\n".join(descriptions)

## 检查是否可以施法
func _can_cast(ability_comp: Node, target: Node = null, context: Dictionary = {}) -> bool:
	if not is_instance_valid(ability_comp): 
		push_error("ActiveAbility: Ability %s can not cast." % ability_id)
		return false
	
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if not is_instance_valid(instigator):
		return false
	
	# 检查标签要求（标签系统集成）
	# 检查必须标签
	if not caster_required_tags.is_empty():
		if not TagManager.has_all_tags(instigator, caster_required_tags):
			print("ActiveAbility: Caster required tags not found for ability %s" % ability_id)
			return false
	
	# 检查阻止标签
	if not caster_blocked_tags.is_empty():
		if TagManager.has_any_tag(instigator, caster_blocked_tags):
			print("ActiveAbility: Caster blocked tags found for ability %s" % ability_id)
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

func _commit_cast(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 检查是否跳过消耗（用于技能链式调用）
	if context.get("skip_cost", false):
		return true
	
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
	
	# 2. 启动执行计时器（自动完成技能）
	if execution_duration > 0.0:
		_start_execution_timer(ability_comp)
	return true

## [核心重构] 施放技能
## 职责：应用状态，不负责完成检查
## 逻辑流：应用状态 -> （由子类或执行计时器负责完成检查）
## [新架构] 使用 Status 系统，通过执行时间自动完成技能
## 
## 设计原则：
## - _on_cast() 只负责应用状态，保持职责单一
## - 完成检查由 _start_execution_timer() 或子类自己管理
## - 子类可以重写此方法，但建议调用 _apply_initial_statuses() 来应用状态
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ActiveAbility: Cannot cast, instigator is not valid")
		return
	
	# 1. 应用初始状态（提取为独立方法，便于子类复用）
	_apply_initial_statuses(instigator, input_target, context)
	
	# 2. 启动执行计时器（如果配置了执行时间）
	# 注意：执行计时器会在时间到期时自动调用 _check_ability_completion()
	if execution_duration > 0.0:
		_start_execution_timer(ability_comp)
	elif execution_duration == 0.0:
		# 瞬时技能：立即完成
		_check_ability_completion()

## 应用初始状态（提取为独立方法，便于子类复用）
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标
## [param] context: Dictionary 上下文信息
func _apply_initial_statuses(instigator: Node, input_target: Node, context: Dictionary) -> void:
	# 传递上下文信息（包括 input_target，供 Status 的目标检测使用）
	var status_context = context.duplicate()
	status_context["input_target"] = input_target
	status_context["ability_id"] = ability_id
	if hit_detector:
		status_context["hit_detector"] = hit_detector
	
	# 应用状态（新架构）
	# Status 系统会自己处理目标检测、筛选和应用效果
	if not statuses.is_empty():
		for status_data in statuses:
			if is_instance_valid(status_data):
				_apply_status(instigator, status_data, status_context)

## 启动执行计时器（自动完成技能）
## [param] ability_comp: Node 技能组件
## 
## 职责：启动计时器，在时间到期时自动完成技能
## 子类可以重写此方法来阻止自动完成（如 ChannelingAbility）
func _start_execution_timer(ability_comp: Node) -> void:
	# 计算执行时间：max(execution_duration, cast_point)
	var exec_time = max(execution_duration, cast_point) if execution_duration > 0.0 else cast_point
	
	# 如果执行时间 <= 0，立即完成
	if exec_time <= 0.0:
		_check_ability_completion()
		return
	
	# 获取 SceneTree（从 ability_comp）
	var scene_tree: SceneTree = null
	if is_instance_valid(ability_comp) and ability_comp.is_inside_tree():
		scene_tree = ability_comp.get_tree()
	
	if not is_instance_valid(scene_tree):
		push_warning("ActiveAbility: Cannot start execution timer, no valid SceneTree found")
		# 回退：立即完成
		_check_ability_completion()
		return
	
	# 创建计时器
	var timer = scene_tree.create_timer(exec_time)
	
	# 计时结束 -> 完成技能
	timer.timeout.connect(func() -> void:
		_check_ability_completion()
	)

## 应用状态（新架构）
## [param] instigator: Node 施法者
## [param] status_data: GameplayStatusData 状态数据
## [param] context: Dictionary 上下文信息
func _apply_status(instigator: Node, status_data: GameplayStatusData, context: Dictionary) -> void:
	if not is_instance_valid(status_data):
		return
	
	# 获取施法者的状态组件
	var status_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayStatusComponent")
	if not is_instance_valid(status_comp):
		push_warning("ActiveAbility: Instigator %s has no GameplayStatusComponent, cannot apply status %s" % [instigator.name, status_data.status_id])
		return
	
	# 应用状态（状态只应用到自己，不处理目标检测）
	# 注意：不再订阅 Status 完成信号，技能完成由执行时间控制
	status_comp.apply_status(status_data, instigator, 1, context)

#region ========== 向后兼容方法（供子类使用，如 MagicCircleAbility、ProjectileAbility）==========

## 应用效果到目标列表（向后兼容，供子类使用）
## [param] effects_to_apply: Array[GameplayEffect]
## [param] instigator: Node 施法者
## [param] targets: Array[Node] 目标列表
## [param] context: Dictionary 上下文
func _apply_effects_to_targets(effects_to_apply: Array, instigator: Node, targets: Array, context: Dictionary) -> void:
	if effects_to_apply.is_empty():
		return
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		for effect in effects_to_apply:
			if not is_instance_valid(effect):
				continue
			_apply_single_effect_to_target(effect, target, instigator, context)

## 为单个单位应用单个效果（向后兼容，供子类使用）
## [param] effect: GameplayEffect 要应用的效果模板
## [param] target: Node 目标单位
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文
func _apply_single_effect_to_target(effect: GameplayEffect, target: Node, instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(effect) or not is_instance_valid(target):
		return
	
	var effect_inst = effect.duplicate(true) as GameplayEffect
	if is_instance_valid(effect_inst):
		effect_inst.apply(target, instigator, context)

## 使用策略对目标进行筛选（向后兼容，供子类使用）
## [param] targets: Array 原始目标列表
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文
## [param] strategy: TargetingStrategy 可选策略
## [param] input_target: Node 可选的直接输入目标
## [return] Array 筛选后的目标
func _filter_targets_with_strategy(targets: Array, instigator: Node, context: Dictionary, strategy: TargetingStrategy, input_target: Node = null) -> Array:
	if targets.is_empty() or not is_instance_valid(strategy):
		return targets
	
	var resolved = strategy.resolve_targets(instigator, input_target, context)
	var filtered: Array[Node] = []
	for target in resolved:
		if target in targets:
			filtered.append(target)
	return filtered

#endregion

## 清除施法效果（基类接口，新架构下通常不需要）
func _clear_cast(_ability_comp: Node, _target: Node) -> void:
	# 新架构下，状态由 Status 系统管理，不需要手动清理
	# 保留此方法以满足基类接口要求
	pass
