extends GameplayAbilityDefinition

## 引导类技能配置模板
##
## 用途：
## 快速创建引导类技能（Channeling Ability），需要持续按住按键才能生效。
##
## 引导类技能的特点：
## - 按住维持（Hold to Channel）：需要持续按住按键，松开则停止
## - 周期性效果（Tick）：每隔一段时间触发一次效果（如持续伤害）
## - 可被打断：支持施法者控制状态和调用方主动取消
## - 完成效果：引导完成时可能有额外效果（可选）
##
## 默认树先判定打断、松手和最大时长，再处理当帧的周期扣费与效果。
## 只有已提交且因松手或达最大时长结束的技能会触发完成效果。
##
## 如果需要更复杂的逻辑，请直接使用基类 GameplayAbilityDefinition 并手动配置 Execution Tree。

## Runs the existing per-tick costs and commits the channel after the first success.
class ChannelingPayment extends BTNode:
	const COMMITTED_KEY: String = "channeling_committed"
	@export var opening_cue: AbilityNodeExecuteCue
	@export var starts_cooldown: bool = false
	@export var costs: Array[VitalCost] = []

	func _tick(instance: BTInstance, delta: float) -> int:
		var ability: GameplayAbilityInstance = instance.blackboard.get_var("ability_instance") as GameplayAbilityInstance
		if not is_instance_valid(ability) or not ability.is_active:
			return Status.FAILURE
		var committed: bool = instance.blackboard.get_var(COMMITTED_KEY, false)
		var context: Dictionary = instance.blackboard.get_var("context", {})
		var payer: Node = context.get("instigator") as Node
		var paid: bool = CostFeature.process_vital_costs(payer, costs, true)
		if not ability.is_active:
			instance.blackboard.set_var(COMMITTED_KEY, false)
			return Status.FAILURE
		if not paid:
			ability.channel_end_reason = &"resource_exhausted"
		if committed:
			return Status.SUCCESS if paid else Status.FAILURE
		var component: GameplayAbilityComponent = context.get("ability_component") as GameplayAbilityComponent
		if not paid:
			if is_instance_valid(component):
				component.report_default_commit(ability, context, false)
			return Status.FAILURE

		if starts_cooldown:
			var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
			if is_instance_valid(cooldown):
				cooldown.start_cooldown(ability)
		if not ability.is_active:
			return Status.FAILURE
		if is_instance_valid(component):
			component.report_default_commit(ability, context, true)
		if not ability.is_active:
			return Status.FAILURE
		if is_instance_valid(opening_cue) and opening_cue.tick(instance, delta) != Status.SUCCESS:
			return Status.FAILURE
		if not ability.is_active:
			return Status.FAILURE
		instance.blackboard.set_var(COMMITTED_KEY, true)
		return Status.SUCCESS

## Checks channel end conditions before any periodic work on this frame.
class ChannelingLoop extends BTNode:
	var preparation: BTSequence
	var work: BTNode
	var periodic: bool = false
	var max_duration: float = 0.0
	var interrupt_tags: Array[StringName] = []

	func _tick(instance: BTInstance, delta: float) -> int:
		var ability: GameplayAbilityInstance = instance.blackboard.get_var("ability_instance") as GameplayAbilityInstance
		if not is_instance_valid(ability) or not ability.is_active:
			return Status.FAILURE
		if _is_interrupted(instance):
			ability.channel_end_reason = &"interrupted"
			return Status.FAILURE
		if instance.blackboard.get_var("event_input_released", false):
			instance.blackboard.set_var("event_input_released", false)
			if not ability.is_active:
				return Status.FAILURE
			ability.channel_end_reason = &"released"
			return Status.SUCCESS

		# A negative value means windup has yet to finish.
		var elapsed: float = _get_storage(instance, -1.0)
		if elapsed < 0.0:
			var result: int = preparation.tick(instance, delta)
			if not ability.is_active:
				return Status.FAILURE
			if result != Status.SUCCESS:
				return result
			elapsed = 0.0
		else:
			elapsed += delta
		_set_storage(instance, elapsed)

		var duration: float = instance.blackboard.get_var("channeling_max_duration", max_duration)
		if duration > 0.0 and elapsed >= duration:
			ability.channel_end_reason = &"max_duration"
			return Status.SUCCESS
		if periodic or not instance.blackboard.get_var(ChannelingPayment.COMMITTED_KEY, false):
			if work.tick(instance, delta) == Status.FAILURE:
				return Status.FAILURE
		return Status.RUNNING

	func _exit(instance: BTInstance) -> void:
		preparation.reset(instance)
		work.reset(instance)

	func _is_interrupted(instance: BTInstance) -> bool:
		if interrupt_tags.is_empty():
			return false
		var context: Dictionary = instance.blackboard.get_var("context", {})
		var caster: Node = context.get("instigator") as Node
		if not is_instance_valid(caster):
			return false
		if TagManager.has_any_tag(caster, interrupt_tags):
			return true
		var statuses: GameplayStatusComponent = GameplayAbilitySystem.get_component_by_interface(
			caster, "GameplayStatusComponent", false
		) as GameplayStatusComponent
		if is_instance_valid(statuses):
			for status_id: StringName in interrupt_tags:
				if statuses.has_status(status_id):
					return true
		return false


@export_group("Quick Config")
@export var animation_name : StringName = &""
@export var animation_speed : float = 1.0
## 技能前摇时间（引导开始前的等待）
@export var pre_cast_delay : float = 0.0
## 技能后摇时间（引导结束后的僵直）
@export var post_cast_delay : float = 0.0
## 技能冷却时间
@export var cooldown_duration : float = 0.0

@export_group("Channeling Settings")
## 最大引导持续时间（秒，0 表示无限制，直到松开按键）
@export var max_duration : float = 0.0
## 周期性效果触发间隔（秒，0 表示不触发周期性效果）
@export var tick_interval : float = 0.5
## 周期性效果列表（每个 tick 对目标触发一次）
@export var tick_effects : Array[GameplayEffect] = []
## 周期性自身效果列表（每个 tick 对自己触发一次，如回血）
@export var tick_self_effects : Array[GameplayEffect] = []
## 周期性消耗（每个 tick 扣除的资源，可选）
@export var tick_costs : Array[VitalCost] = []
## 完成效果列表（已提交后松手或达到最大引导时长时触发，可选）
@export var completion_effects : Array[GameplayEffect] = []
## 引导期间 Cue（在引导开始时执行，引导结束时停止）
@export var channeling_cue: GameplayCue = null
## 是否允许移动引导，供调用方判断移动时是否取消
@export var is_mobile : bool = false
## 目标获取策略
@export var targeting_strategy: TargetingStrategy = null
## 目标 Key
@export var target_key: String = "targets"

@export_group("Interruption Settings")
## 打断标签列表（如果施法者拥有这些标签，引导会被打断）
@export var interrupt_tags: Array[StringName] = [&"state.stunned", &"state.silenced"]

# ========== 行为树缓存（享元模式） ==========
## 缓存的默认行为树（所有实例共享，避免重复构建）
## 只在第一次创建实例时构建，之后所有实例共享
var _cached_default_tree: BTNode = null

func uses_default_channeling() -> bool:
	return execution_tree == null

## 重写基类的工厂方法
## 在创建实例时自动注入 Feature 和构建行为树（不修改 Definition，避免资源污染）
func create_instance(owner: Node) -> GameplayAbilityInstance:
	# 1. 验证配置
	_validate_configuration()

	# 2. 获取执行树（优先使用用户配置，否则使用缓存的默认树）
	var tree_to_use: BTNode = _get_execution_tree()

	# 3. 临时设置 execution_tree（仅用于创建 Instance，不污染资源）
	var original_tree: BTNode = execution_tree
	execution_tree = tree_to_use

	# 4. 调用父类创建实例（这会复制 features 到 instance）
	var instance: GameplayAbilityInstance = super(owner)

	# 5. 立即恢复 execution_tree（避免资源污染）
	execution_tree = original_tree

	# 6. 在 Instance 中动态注入 Feature（不修改 Definition，避免资源污染）
	_inject_features_to_instance(instance)

	# 7. 【关键】将引导参数写入黑板，允许 Modifier 在运行时修改
	# 这些参数会被 BTRepeatPeriodic 和 ChannelingLoop 读取
	if is_instance_valid(instance) and is_instance_valid(instance.get_blackboard()):
		var blackboard: BTBlackboard = instance.get_blackboard()
		blackboard.set_var("channeling_tick_interval", tick_interval)
		blackboard.set_var("channeling_max_duration", max_duration)
		blackboard.set_var("channeling_is_mobile", is_mobile)

	return instance

## 获取执行树（优先使用用户配置，否则使用缓存的默认树）
## 符合享元模式：所有实例共享同一个行为树
## [return] BTNode 执行树
func _get_execution_tree() -> BTNode:
	# 如果用户手动配置了，使用用户的
	if is_instance_valid(execution_tree):
		return execution_tree

	# 如果已缓存，使用缓存的（享元模式）
	if is_instance_valid(_cached_default_tree):
		return _cached_default_tree

	# 构建并缓存（只构建一次，之后所有实例共享）
	_cached_default_tree = _build_default_behavior_tree()
	return _cached_default_tree

## 在 Instance 中注入 Feature（不修改 Definition，避免资源污染）
## [param] instance: GameplayAbilityInstance 技能实例
func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
	# 注入 CooldownFeature（如果配置了冷却时间且不存在）
	if cooldown_duration > 0.0:
		if not _has_feature(instance, CooldownFeature):
			var cd_feature: CooldownFeature = CooldownFeature.new()
			cd_feature.cooldown_duration = cooldown_duration
			instance.add_feature(cd_feature.feature_name, cd_feature)

## 检查 Instance 是否已有指定类型的 Feature
## [param] instance: GameplayAbilityInstance 技能实例
## [param] feature_type: GDScript Feature 类型
## [return] bool 是否存在
func _has_feature(instance: GameplayAbilityInstance, feature_type: GDScript) -> bool:
	var all_features: Array[GameplayAbilityFeature] = instance.get_features()
	for feature: GameplayAbilityFeature in all_features:
		if feature.get_script() == feature_type:
			return true
	return false

## 验证配置的合理性
func _validate_configuration() -> void:
	# 验证：前摇和后摇时间应该非负
	if pre_cast_delay < 0.0:
		push_error("ChannelingAbilityDefinition [%s]: pre_cast_delay 不能为负数 (%.2f)" % [ability_id, pre_cast_delay])
		pre_cast_delay = 0.0

	if post_cast_delay < 0.0:
		push_error("ChannelingAbilityDefinition [%s]: post_cast_delay 不能为负数 (%.2f)" % [ability_id, post_cast_delay])
		post_cast_delay = 0.0

	# 验证：冷却时间应该非负
	if cooldown_duration < 0.0:
		push_error("ChannelingAbilityDefinition [%s]: cooldown_duration 不能为负数 (%.2f)" % [ability_id, cooldown_duration])
		cooldown_duration = 0.0

	# 验证：动画速度应该为正
	if animation_speed <= 0.0:
		push_error("ChannelingAbilityDefinition [%s]: animation_speed 必须为正数 (%.2f)" % [ability_id, animation_speed])
		animation_speed = 1.0

	# 验证：最大引导持续时间应该非负
	if max_duration < 0.0:
		push_error("ChannelingAbilityDefinition [%s]: max_duration 不能为负数 (%.2f)" % [ability_id, max_duration])
		max_duration = 0.0

	# 验证：周期性触发间隔应该为正（如果配置了周期性效果）
	if tick_interval <= 0.0:
		if not tick_effects.is_empty() or not tick_self_effects.is_empty() or not tick_costs.is_empty():
			push_error("ChannelingAbilityDefinition [%s]: tick_interval 必须为正数 (%.2f)" % [ability_id, tick_interval])
			tick_interval = 0.5

	# 验证：如果配置了周期性效果，应该配置了触发间隔
	if (not tick_effects.is_empty() or not tick_self_effects.is_empty()) and tick_interval <= 0.0:
		push_warning(
			"ChannelingAbilityDefinition [%s]: 配置了周期性效果但 tick_interval 无效 (%.2f)。\n" % [ability_id, tick_interval] +
			"周期性效果可能不会触发。"
		)

	# 验证：如果配置了 targeting_strategy，应该配置了 tick_effects
	if is_instance_valid(targeting_strategy):
		if tick_effects.is_empty() and completion_effects.is_empty():
			push_warning(
				"ChannelingAbilityDefinition [%s]: 配置了 targeting_strategy 但没有配置 tick_effects 或 completion_effects。\n" % ability_id +
				"targeting_strategy 可能不会被使用。"
			)

## 动态构建行为树结构 (构建的是 BTNode 资源图，而不是 Instance)
func _build_default_behavior_tree() -> BTNode:
	var root_sequence: BTSequence = BTSequence.new()
	var nodes: Array[BTNode] = []

	# 1. 播放动画（异步，不等待）
	if not animation_name.is_empty():
		var anim_node: AbilityNodePlayAnimation = AbilityNodePlayAnimation.new()
		anim_node.animation_name = animation_name
		anim_node.animation_speed = animation_speed
		anim_node.wait_for_finish = false
		anim_node.node_id = "play_animation"
		nodes.append(anim_node)

	var loop: ChannelingLoop = ChannelingLoop.new()
	loop.node_id = "channeling_loop"
	loop.max_duration = max_duration
	loop.interrupt_tags = interrupt_tags.duplicate()
	loop.preparation = BTSequence.new()
	loop.preparation.node_id = "channel_preparation"

	if pre_cast_delay > 0.0:
		var wait: BTWait = BTWait.new()
		wait.duration = pre_cast_delay
		wait.node_id = "pre_cast_delay"
		loop.preparation.children.append(wait)

	if is_instance_valid(targeting_strategy):
		var target_search_node: AbilityNodeTargetSearch = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
		target_search_node.write_to_key = target_key
		target_search_node.node_id = "target_search"
		loop.preparation.children.append(target_search_node)

	var payment: ChannelingPayment = ChannelingPayment.new()
	payment.node_id = "channel_payment"
	payment.starts_cooldown = cooldown_duration > 0.0
	if is_instance_valid(channeling_cue):
		var execute_cue: AbilityNodeExecuteCue = AbilityNodeExecuteCue.new()
		execute_cue.cue = channeling_cue
		execute_cue.target_key = target_key
		execute_cue.save_instance_key = "channeling_cue_instance"
		execute_cue.node_id = "execute_channeling_cue"
		payment.opening_cue = execute_cue

	loop.work = payment
	loop.periodic = tick_interval > 0.0 and (not tick_effects.is_empty() or not tick_self_effects.is_empty())
	if loop.periodic:
		for cost: VitalCost in tick_costs:
			if is_instance_valid(cost):
				payment.costs.append(cost)

		var tick_sequence: BTSequence = BTSequence.new()
		tick_sequence.node_id = "tick_sequence"
		tick_sequence.children.append(payment)

		if not tick_effects.is_empty():
			var apply_tick_effect: AbilityNodeApplyEffect = AbilityNodeApplyEffect.new()
			apply_tick_effect.effects = tick_effects.duplicate()
			apply_tick_effect.target_key = target_key
			apply_tick_effect.node_id = "apply_tick_effect"
			tick_sequence.children.append(apply_tick_effect)

		if not tick_self_effects.is_empty():
			var apply_tick_self_effect: AbilityNodeApplyEffect = AbilityNodeApplyEffect.new()
			apply_tick_self_effect.effects = tick_self_effects.duplicate()
			apply_tick_self_effect.target_key = ""
			apply_tick_self_effect.use_instigator_as_fallback = true
			apply_tick_self_effect.node_id = "apply_tick_self_effect"
			tick_sequence.children.append(apply_tick_self_effect)

		var repeat_periodic: BTRepeatPeriodic = BTRepeatPeriodic.new()
		repeat_periodic.period = tick_interval
		repeat_periodic.period_key = "channeling_tick_interval"
		repeat_periodic.return_success_on_failure = false
		repeat_periodic.node_id = "repeat_periodic"
		repeat_periodic.child = tick_sequence
		loop.work = repeat_periodic
	nodes.append(loop)

	# A release during windup skips completion effects and recovery.
	var require_commit: BTCheckVarAction = BTCheckVarAction.new()
	require_commit.key = ChannelingPayment.COMMITTED_KEY
	require_commit.value = true
	require_commit.node_id = "require_channel_commit"
	nodes.append(require_commit)

	# 5.5 停止引导 Cue（如果配置了）
	if is_instance_valid(channeling_cue):
		var stop_cue_node: AbilityNodeStopCue = AbilityNodeStopCue.new()
		stop_cue_node.cue_instance_key = "channeling_cue_instance"
		stop_cue_node.node_id = "stop_channeling_cue"
		nodes.append(stop_cue_node)

	# 6. 应用完成效果（如果配置了）
	if not completion_effects.is_empty():
		var apply_completion_effect: AbilityNodeApplyEffect = AbilityNodeApplyEffect.new()
		apply_completion_effect.effects = completion_effects.duplicate()
		apply_completion_effect.target_key = target_key
		apply_completion_effect.node_id = "apply_completion_effect"
		nodes.append(apply_completion_effect)

	# 7. 后摇等待
	if post_cast_delay > 0.0:
		var wait: BTWait = BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)

	# 赋值子节点
	root_sequence.children = nodes
	root_sequence.node_id = "channeling_ability_sequence"
	return root_sequence
