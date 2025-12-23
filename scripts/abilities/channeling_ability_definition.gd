extends GameplayAbilityDefinition
class_name ChannelingAbilityDefinition

## 引导类技能配置模板
## 
## 用途：
## 快速创建引导类技能（Channeling Ability），需要持续按住按键才能生效。
## 
## 引导类技能的特点：
## - 按住维持（Hold to Channel）：需要持续按住按键，松开则停止
## - 周期性效果（Tick）：每隔一段时间触发一次效果（如持续伤害）
## - 可被打断：松开按键、移动（如果配置为静止引导）、被控制等
## - 完成效果：引导完成时可能有额外效果（可选）
## 
## 行为树结构：
## 1. 开始引导：播放动画、应用初始效果、提交冷却
## 2. 引导循环（并行）：
##    - 周期性效果：使用 BTRepeatPeriodic 周期性触发效果
##    - 等待输入释放：使用 BTWaitSignal 等待 event_input_received 信号
##    - 检查打断条件：检查是否被控制、是否移动（如果配置为静止引导）
## 3. 完成引导：应用完成效果（如果配置）
## 
## 如果需要更复杂的逻辑，请直接使用基类 GameplayAbilityDefinition 并手动配置 Execution Tree。

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
## 完成效果列表（仅在完整引导结束时触发，可选）
@export var completion_effects : Array[GameplayEffect] = []
## 引导期间 Cue（在引导开始时执行，引导结束时停止）
@export var channeling_cue: GameplayCue = null
## 是否允许移动引导（false = 静止引导，移动会打断）
@export var is_mobile : bool = false
## 目标获取策略
@export var targeting_strategy: TargetingStrategy = null
## 目标 Key
@export var target_key: String = "targets"

@export_group("Interruption Settings")
## 打断标签列表（如果施法者拥有这些标签，引导会被打断）
@export var interrupt_tags: Array[StringName] = [&"state.stunned", &"state.silenced"]

## 创建技能实例
func create_instance(owner: Node) -> GameplayAbilityInstance:
	# 动态构建行为树（如果用户没在编辑器里手动拖树）
	if execution_tree == null:
		execution_tree = _build_default_behavior_tree()

	# 调用父类创建实例
	var instance = super.create_instance(owner)
	
	# 【关键】将引导参数写入黑板，允许 Modifier 在运行时修改
	# 这些参数会被 BTRepeatPeriodic 和 BTWait 读取
	if is_instance_valid(instance) and is_instance_valid(instance.get_blackboard()):
		var blackboard = instance.get_blackboard()
		blackboard.set_var("channeling_tick_interval", tick_interval)
		blackboard.set_var("channeling_max_duration", max_duration)
		blackboard.set_var("channeling_is_mobile", is_mobile)
	
	return instance

## 动态构建行为树结构
func _build_default_behavior_tree() -> BTNode:
	var root_sequence = BTSequence.new()
	var nodes: Array[BTNode] = []

	# 1. 播放动画（异步，不等待）
	if not animation_name.is_empty():
		var anim_node = AbilityNodePlayAnimation.new()
		anim_node.animation_name = animation_name
		anim_node.animation_speed = animation_speed
		anim_node.wait_for_finish = false 
		anim_node.node_id = "play_animation"
		nodes.append(anim_node)
	
	# 2. 前摇等待
	if pre_cast_delay > 0.0:
		var wait = BTWait.new()
		wait.duration = pre_cast_delay
		wait.node_id = "pre_cast_delay"
		nodes.append(wait)
		
	# 3. 提交冷却（前摇结束后进CD）
	if cooldown_duration > 0.0:
		var commit_cd = AbilityNodeCommitCooldown.new()
		commit_cd.node_id = "commit_cooldown"
		nodes.append(commit_cd)
	
	# 4. 查找目标（如果配置了目标策略）
	if is_instance_valid(targeting_strategy):
		var target_search_node = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
		target_search_node.write_to_key = target_key
		target_search_node.node_id = "target_search"
		nodes.append(target_search_node)
	
	# 4.5 执行引导 Cue（如果配置了）
	if is_instance_valid(channeling_cue):
		var execute_cue_node = AbilityNodeExecuteCue.new()
		execute_cue_node.cue = channeling_cue
		execute_cue_node.target_key = target_key
		execute_cue_node.save_instance_key = "channeling_cue_instance"
		execute_cue_node.node_id = "execute_channeling_cue"
		nodes.append(execute_cue_node)

	# 5. 引导循环（并行处理：周期性效果 + 等待输入释放 + 检查打断条件）
	var channeling_parallel = BTParallel.new()
	channeling_parallel.policy = BTParallel.Policy.SUCCEED_ON_ONE  # 任意一个完成即结束
	channeling_parallel.node_id = "channeling_parallel"
	
	var parallel_children: Array[BTNode] = []
	
	# 5.1 周期性效果（如果配置了）
	if tick_interval > 0.0 and not tick_effects.is_empty():
		var periodic_sequence = BTSequence.new()
		periodic_sequence.node_id = "periodic_sequence"
		
		# 周期性重复节点
		var repeat_periodic = BTRepeatPeriodic.new()
		repeat_periodic.period = tick_interval  # 默认值（如果黑板没有值则使用此值）
		repeat_periodic.period_key = "channeling_tick_interval"  # 优先从黑板读取
		repeat_periodic.execute_immediately = true
		repeat_periodic.return_success_on_failure = true  # 消耗不足时正常结束
		repeat_periodic.node_id = "repeat_periodic"
		
		# 周期性效果序列
		var tick_sequence = BTSequence.new()
		tick_sequence.node_id = "tick_sequence"
		
		var tick_nodes: Array[BTNode] = []
		
		# 检查周期性消耗（如果配置了）
		if not tick_costs.is_empty():
			for cost in tick_costs:
				if not is_instance_valid(cost):
					continue
				var check_cost = AbilityNodeApplyCost.new()
				check_cost.vital_id = cost.vital_id
				check_cost.cost_amount = cost.amount
				check_cost.allow_overdraft = cost.allow_overdraft
				check_cost.check_only = false  # 检查并消耗
				# 注意：AbilityNodeApplyCost 使用 _get_target_list，默认会使用 instigator 作为回退
				check_cost.node_id = "check_tick_cost_%s" % cost.vital_id
				tick_nodes.append(check_cost)
		
		# 应用周期性效果（对目标）
		if not tick_effects.is_empty():
			var apply_tick_effect = AbilityNodeApplyEffect.new()
			apply_tick_effect.effects = tick_effects.duplicate()
			apply_tick_effect.target_key = target_key
			apply_tick_effect.node_id = "apply_tick_effect"
			tick_nodes.append(apply_tick_effect)
		
		# 应用周期性自身效果（对自己，如回血）
		if not tick_self_effects.is_empty():
			var apply_tick_self_effect = AbilityNodeApplyEffect.new()
			apply_tick_self_effect.effects = tick_self_effects.duplicate()
			apply_tick_self_effect.target_key = ""  # 空字符串，配合 use_instigator_as_fallback 使用
			apply_tick_self_effect.use_instigator_as_fallback = true  # 使用 instigator 作为目标
			apply_tick_self_effect.node_id = "apply_tick_self_effect"
			tick_nodes.append(apply_tick_self_effect)
		
		tick_sequence.children = tick_nodes
		repeat_periodic.child = tick_sequence
		periodic_sequence.children = [repeat_periodic]
		parallel_children.append(periodic_sequence)
	
	# 5.2 等待输入释放（或达到最大持续时间）
	var wait_sequence = BTSequence.new()
	wait_sequence.node_id = "wait_sequence"
	
	var wait_nodes: Array[BTNode] = []
	
	# 如果有最大持续时间，使用 BTSelector 选择：等待输入释放 OR 等待最大持续时间
	if max_duration > 0.0:
		var wait_selector = BTSelector.new()
		wait_selector.node_id = "wait_selector"
		
		# 选项1：等待输入释放（按键松开）
		# 注意：使用 event_input_released 而不是 event_input_received
		# event_input_received 是按键按下时触发，event_input_released 是按键释放时触发
		var wait_input = BTWaitSignal.new()
		wait_input.signal_key = "event_input_released"
		wait_input.timeout = 999999.0  # 无限等待，直到信号触发
		wait_input.consume_signal = true
		wait_input.node_id = "wait_input_release"
		
		# 选项2：等待最大持续时间
		var wait_duration = BTWait.new()
		wait_duration.duration = max_duration  # 默认值（如果黑板没有值则使用此值）
		wait_duration.duration_key = "channeling_max_duration"  # 优先从黑板读取
		wait_duration.node_id = "wait_max_duration"
		
		wait_selector.children = [wait_input, wait_duration]
		wait_nodes.append(wait_selector)
	else:
		# 无最大持续时间，只等待输入释放（按键松开）
		var wait_input = BTWaitSignal.new()
		wait_input.signal_key = "event_input_released"
		wait_input.timeout = 999999.0  # 无限等待，直到信号触发
		wait_input.consume_signal = true
		wait_input.node_id = "wait_input_release"
		wait_nodes.append(wait_input)
	
	wait_sequence.children = wait_nodes
	parallel_children.append(wait_sequence)
	
	# 5.3 检查打断条件（如果配置了）
	if not interrupt_tags.is_empty():
		var interrupt_sequence = BTSequence.new()
		interrupt_sequence.node_id = "interrupt_sequence"
		
		var interrupt_nodes: Array[BTNode] = []
		
		# 检查打断标签（使用 BTRepeatPeriodic 持续检查）
		var check_interrupt_repeat = BTRepeatPeriodic.new()
		check_interrupt_repeat.period = 0.1  # 每 0.1 秒检查一次
		check_interrupt_repeat.execute_immediately = true
		check_interrupt_repeat.return_success_on_failure = false  # 被打断时返回失败
		check_interrupt_repeat.node_id = "check_interrupt_repeat"
		
		var check_interrupt_sequence = BTSequence.new()
		check_interrupt_sequence.node_id = "check_interrupt_sequence"
		
		# 检查是否拥有打断标签
		var check_status = AbilityNodeCheckStatus.new()
		check_status.status_ids = interrupt_tags.duplicate()
		check_status.status_exists_key = "is_interrupted"
		check_status.target_key = "instigator"  # 检查施法者自己
		check_status.node_id = "check_interrupt_status"
		
		# 如果状态存在（被打断），返回 FAILURE
		# 使用 BTCheckVarAction 来检查 is_interrupted
		var check_var = BTCheckVarAction.new()
		check_var.key = "is_interrupted"
		check_var.value = true
		check_var.node_id = "check_is_interrupted"
		
		# 如果被打断，返回 FAILURE（这会停止 BTRepeatPeriodic）
		check_interrupt_sequence.children = [check_status, check_var]
		check_interrupt_repeat.child = check_interrupt_sequence
		interrupt_sequence.children = [check_interrupt_repeat]
		parallel_children.append(interrupt_sequence)
	
	channeling_parallel.children = parallel_children
	nodes.append(channeling_parallel)
	
	# 5.5 停止引导 Cue（如果配置了）
	if is_instance_valid(channeling_cue):
		var stop_cue_node = AbilityNodeStopCue.new()
		stop_cue_node.cue_instance_key = "channeling_cue_instance"
		stop_cue_node.node_id = "stop_channeling_cue"
		nodes.append(stop_cue_node)
	
	# 6. 应用完成效果（如果配置了）
	if not completion_effects.is_empty():
		var apply_completion_effect = AbilityNodeApplyEffect.new()
		apply_completion_effect.effects = completion_effects.duplicate()
		apply_completion_effect.target_key = target_key
		apply_completion_effect.node_id = "apply_completion_effect"
		nodes.append(apply_completion_effect)
	
	# 7. 后摇等待
	if post_cast_delay > 0.0:
		var wait = BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)
	
	# 赋值子节点
	root_sequence.children = nodes
	root_sequence.node_id = "channeling_ability_sequence"
	return root_sequence

