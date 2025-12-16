extends GameplayAbility
class_name ActiveAbility

## 主动技能数据 (v2.0 Refactored)
## 核心改进：分离了"对己效果"和"对敌效果"，解耦了目标获取逻辑

@export_group("Casting Rules")
@export var cooldown_duration: float = 0.0  ## 技能冷却时间（基础值）
@export var costs: Array[AbilityCostBase] = []  ## 技能消耗器数组（支持多种消耗类型）
@export var cast_point: float = 0.5  ## 施法前摇时间 (动画关键帧)

@export_group("Level Scaling")
## 冷却时间随等级变化（可选）
## 如果设置了此值，冷却时间会根据技能等级自动计算
## 如果未设置，则使用固定的 cooldown_duration
@export var cooldown_scalable: ScalableValue = null
## 消耗随等级变化（可选）
## 如果设置了此值，消耗会根据技能等级自动计算
## 注意：当前版本消耗系统暂不支持等级成长，此属性为预留接口
@export var cost_scalable: ScalableValue = null
## 技能执行时间（秒）
## 如果 > 0，技能会在执行时间结束后自动完成
## 如果 <= 0，则使用 cast_point 作为执行时间
## 最终执行时间 = max(execution_duration, cast_point)
@export var execution_duration: float = 0.0
# @export var cast_range: float = 8.0  ## 施法距离
## 目标获取策略
## 如果设置了此策略，将使用策略来获取目标
## 策略可以包含 hit_detector（如 HitDetectorTargetingStrategy），也可以实现更复杂的目标获取逻辑
## 
## 推荐策略：
## - HitDetectorTargetingStrategy: 简单的目标检测（普通攻击、范围技能等）
## - AreaTargetingStrategy: 区域目标检测（AOE技能）
## - UnitTargetingStrategy: 单位目标检测（指向性技能）
## - GroundTargetingStrategy: 地面目标检测（放置类技能）
## - SelfTargetingStrategy: 只对自己生效
## - NoTargetingStrategy: 无目标（战吼、光环等）
@export var targeting_strategy: TargetingStrategy = NoTargetingStrategy.new()

@export var animation_name: StringName = &"cast_spell_default"  ## 动画名称
@export var indicator_data: TargetIndicatorData = null  ## 目标指示器数据

@export_group("Effects")
## [DEPRECATED] 直接执行的效果列表. 推荐使用 'statuses' 数组来定义技能逻辑.
##
## 这个属性为了向后兼容和快速原型而保留. 在新的三层架构 (v3.0+) 中,
## 所有逻辑都应该封装在 GameplayStatusData 中, 即使是瞬时效果 (使用 duration = 0 的 Status).
## 这能确保所有技能都遵循统一的 Ability -> Status -> Effect 执行路径.
@export var effects: Array[GameplayEffect] = []

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
	# 如果设置了 cooldown_scalable，根据等级计算冷却时间
	if is_instance_valid(cooldown_scalable):
		return cooldown_scalable.get_value_at_level(current_level)
	# 否则使用固定值
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
	
	# 状态效果 (新架构)
	if not statuses.is_empty():
		descriptions.append("[状态]")
		for status_data in statuses:
			if is_instance_valid(status_data):
				descriptions.append("- %s" % status_data.status_display_name)
				descriptions.append("  %s" % status_data.get_effects_description())

	# 直接效果 (旧架构, 仅作补充或向后兼容)
	if not effects.is_empty():
		if not descriptions.is_empty():
			descriptions.append("")
		descriptions.append("[直接效果 - 已弃用]")
		for effect in effects:
			if is_instance_valid(effect):
				descriptions.append("- %s" % effect.get_description())

	return "\n".join(descriptions)

## [重写] 等级改变时的回调
## 当技能等级改变时，重新计算冷却和消耗
func _on_level_changed() -> void:
	super()
	# 重新计算冷却时间（如果设置了 cooldown_scalable）
	# 注意：这里只是更新基础值，实际冷却时间在 get_cooldown_duration() 中动态计算
	# 如果需要立即更新当前冷却，可以在这里处理
	# 当前设计：冷却时间在每次 get_cooldown_duration() 时动态计算，无需手动更新

## 检查是否可以施法
func _can_cast(ability_comp: Node, target: Node = null, context: Variant = {}) -> bool:
	var ctx = ContextUtils.to_context(context)
	if not is_instance_valid(ability_comp): 
		push_error("ActiveAbility: Ability %s can not cast." % ability_id)
		return false
	
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if not is_instance_valid(instigator):
		return false
	
	# 【标签系统】检查是否被眩晕或沉默（无法释放技能）
	if TagManager.has_tag(instigator, &"state.stunned") or TagManager.has_tag(instigator, &"state.silenced"):
		print("ActiveAbility: Caster is stunned or silenced, cannot cast ability %s" % ability_id)
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

func _commit_cast(ability_comp: Node, context: AbilityContext) -> bool:
	# 检查是否跳过消耗（用于技能链式调用）
	if context.skip_cost:
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
## 职责：应用状态或效果，不负责完成检查.
##
## [新架构] v3.0 推荐使用 Status 系统.
## 逻辑流:
## 1. 优先应用 statuses 数组中的状态.
## 2. 如果 statuses 为空, 则回退到旧的, 直接应用 effects 数组.
## 3. 启动执行计时器 (如果 execution_duration > 0), 在时间到期时自动完成技能.
func _on_cast(ability_comp: Node, input_target: Node, context: AbilityContext) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ActiveAbility: Cannot cast, instigator is not valid")
		return

	# 新架构 (v3.0+): 优先使用 Status 系统
	if not statuses.is_empty():
		_apply_initial_statuses(instigator, input_target, context)
	# 旧架构 (向后兼容): 如果没有配置 Status, 则回退到直接应用 Effect
	elif not effects.is_empty():
		push_warning("ActiveAbility: Ability '%s' is using deprecated direct effects. Consider wrapping them in a GameplayStatusData." % ability_id)
		_apply_initial_effects(instigator, input_target, context)

	# 应用 Modifier 追加的额外效果 (新旧架构通用)
	_apply_modifier_effects(instigator, input_target, context)

	# 启动执行计时器, 决定技能何时结束
	if execution_duration > 0.0:
		_start_execution_timer(ability_comp)
	# 如果没有持续时间, 并且没有状态需要等待, 则认为是瞬时技能, 立即完成
	elif statuses.is_empty():
		_check_ability_completion()
	# 如果有状态, 技能的完成将由状态的生命周期决定 (通过 GameplayAbility 的 _on_status_completed).


## 应用由 Modifier 动态追加的额外效果
func _apply_modifier_effects(instigator: Node, input_target: Node, context: AbilityContext) -> void:
	if context.extra_effects.is_empty():
		return

	var effect_context = context.duplicate()
	effect_context.input_target = input_target
	effect_context.ability_id = ability_id
	
	# 确定目标列表
	var targets: Array[Node] = []
	if context.apply_extra_effects_to_all_targets:
		# 应用到所有目标（使用 targeting_strategy）
		# 需要转换为 Dictionary 传递给策略
		var strategy_dict = effect_context.to_dict()
		targets = _get_targets_for_application(instigator, input_target, strategy_dict)
	else:
		# 只应用到 input_target
		if is_instance_valid(input_target):
			targets = [input_target]
	
	# 为所有目标应用额外效果
	for effect_data in context.extra_effects:
		if not is_instance_valid(effect_data):
			continue
		
		for target in targets:
			if is_instance_valid(target):
				_apply_single_effect_to_target(effect_data, target, instigator, effect_context)


## [已弃用] 应用初始直接效果（为向后兼容保留）
func _apply_initial_effects(instigator: Node, input_target: Node, context: AbilityContext) -> void:
	# 准备效果上下文
	var effect_context = context.duplicate()
	effect_context.input_target = input_target
	effect_context.ability_id = ability_id
	
	# 应用直接效果
	if not effects.is_empty():
		for effect_data in effects:
			if not is_instance_valid(effect_data):
				continue
			
			# 需要转换为 Dictionary 传递给策略
			var strategy_dict = effect_context.to_dict()
			var targets: Array[Node] = _get_targets_for_application(instigator, input_target, strategy_dict)
			
			for target in targets:
				if is_instance_valid(target):
					_apply_single_effect_to_target(effect_data, target, instigator, effect_context)

## 应用初始状态（提取为独立方法，便于子类复用）
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标
## [param] context: AbilityContext 上下文信息
func _apply_initial_statuses(instigator: Node, input_target: Node, context: AbilityContext) -> void:
	# 使用基类方法，传入本技能的 targeting_strategy
	_apply_statuses_to_targets(instigator, input_target, context, targeting_strategy)

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

## 获取应用目标列表（统一的目标获取逻辑）
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标
## [param] context: Dictionary 上下文信息
## [return] Array[Node] 目标列表
func _get_targets_for_application(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
	# 如果配置了 targeting_strategy，使用它
	if is_instance_valid(targeting_strategy):
		var targets = targeting_strategy.resolve_targets(instigator, input_target, context)
		return targets
	
	# 默认：只应用到施法者
	push_error("ActiveAbility: No targeting strategy found for ability %s" % ability_id)
	return []

# 注意：_apply_status_to_target 已移至基类 GameplayAbility，子类可直接使用

#region ========== 向后兼容方法（供子类使用，如 MagicCircleAbility、ProjectileAbility）==========

## 应用效果到目标列表（向后兼容，供子类使用）
## [param] effects_to_apply: Array[GameplayEffect]
## [param] instigator: Node 施法者
## [param] targets: Array[Node] 目标列表
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func _apply_effects_to_targets(effects_to_apply: Array, instigator: Node, targets: Array, context: Variant) -> void:
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
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func _apply_single_effect_to_target(effect: GameplayEffect, target: Node, instigator: Node, context: Variant) -> void:
	if not is_instance_valid(effect) or not is_instance_valid(target):
		return
	
	var ctx = ContextUtils.to_context(context)
	
	# 【Modifier 钩子】效果应用前通知（用于 DamageMultiplierModifier 等）
	var modifier_comp: GameplayModifierComponent = GameplayAbilitySystem.get_component_by_interface(
		instigator,
		"GameplayModifierComponent"
	)
	if is_instance_valid(modifier_comp):
		modifier_comp.notify_effect_applied(effect, target, instigator, ctx)
	
	var effect_inst = effect.duplicate(true) as GameplayEffect
	if is_instance_valid(effect_inst):
		effect_inst.apply(target, instigator, ctx)

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
