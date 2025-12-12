extends RefCounted
class_name GameplayStatusInstance

## 状态实例
## 管理一个状态的生命周期，包括持续时间、层数、效果执行等

var status_data: GameplayStatusData
var owner_component: Node  ## 状态组件（采用鸭子类型，不依赖具体类型）
var instigator: Node  ## 施加者
var stacks: int = 1

# 智能处理器追踪已注册的监听器
var stateful_effects: Array[GameplayEffect] = []  # 追踪需要在 remove 时调用的效果

var _duration_timer: Timer = null  # 用于自动移除的计时器
var _periodic_timer: Timer = null  # 周期性效果计时器（状态只有一个 period）
var _is_connected_to_event_bus: bool = false  # 是否已连接到统一事件系统

## 状态完成信号
## 当状态完成时（瞬时状态立即完成，持续状态在移除时完成）发出此信号
## Ability 会订阅此信号来判断技能是否完成
signal status_completed(status_instance: GameplayStatusInstance)

func _init(
		p_data: GameplayStatusData = null, 
		p_owner_component: Node = null, 
		p_instigator: Node = null, 
		p_stacks: int = 1) -> void:
	status_data = p_data
	owner_component = p_owner_component
	instigator = p_instigator
	stacks = p_stacks

	_create_duration_timer()

func get_id() -> StringName:
	if not is_instance_valid(status_data):
		return &""
	return status_data.status_id

func get_owner_component() -> Node:
	return owner_component

## 获取目标实体（通过owner_component获取）
func get_target_entity() -> Node:
	if not is_instance_valid(owner_component):
		return null
	# 假设owner_component是节点的子节点，获取父节点作为实体
	return owner_component.get_parent()

## 状态被施加时，应用所有效果
func apply(context: Dictionary = {}) -> void:
	# 1. 检测目标（如果配置了目标检测）
	var targets_to_apply: Array[Node] = _resolve_targets(context)
	
	# 2. 对每个目标应用效果
	for target in targets_to_apply:
		if is_instance_valid(target):
			_apply_all_effects_to_target(target, context)
	
	# 3. 如果是瞬时效果（duration = 0），立即移除并发出完成信号
	if status_data.duration == 0.0:
		remove()
		# 发出完成信号（瞬时状态在应用完成后立即完成）
		status_completed.emit(self)
		return
	
	# 4. 注册周期性效果（使用状态级别的 period）
	if status_data.period > 0.0:
		_create_periodic_timer()
	
	# 5. 连接到统一游戏事件系统
	# 如果状态配置了 trigger_on_events 或 event_to_listen，需要连接事件总线
	if not _is_connected_to_event_bus:
		var needs_event_bus = not status_data.trigger_on_events.is_empty() or status_data.event_to_listen != &""
		if needs_event_bus:
			AbilityEventBus.game_event_occurred.connect(_on_game_event_occurred)
			_is_connected_to_event_bus = true
	
	# 6. 应用状态标签（标签系统集成）
	_apply_status_tags()
	
	# 7. 执行状态 Cue（视觉反馈）
	_execute_status_cue()

## 状态被移除时，移除所有效果
func remove() -> void:
	# 1. 停止持续时间计时器
	if is_instance_valid(_duration_timer):
		_duration_timer.stop()
		_duration_timer.queue_free()
		_duration_timer = null

	# 2. 移除所有效果
	_remove_all_effects()

	# 3. 停止周期性计时器
	if is_instance_valid(_periodic_timer):
		_periodic_timer.stop()
		_periodic_timer.queue_free()
		_periodic_timer = null
	
	# 4. 断开统一游戏事件系统的连接
	if _is_connected_to_event_bus:
		if AbilityEventBus.game_event_occurred.is_connected(_on_game_event_occurred):
			AbilityEventBus.game_event_occurred.disconnect(_on_game_event_occurred)
		_is_connected_to_event_bus = false
	
	# 5. 移除状态标签（标签系统集成）
	_remove_status_tags()
	
	# 6. 停止状态 Cue（清理视觉反馈）
	_stop_status_cue()
	
	# 7. 发出完成信号（持续状态在移除时完成）
	status_completed.emit(self)

## 处理事件（用于事件监听型效果）
## 此方法用于处理通过统一事件系统触发的事件
func handle_event(event_id: StringName, context: Dictionary) -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 检查状态是否应该响应这个事件
	if not status_data.can_trigger_on_event(event_id):
		return
	
	# 检查是否是状态级别的事件监听
	if status_data.event_to_listen == event_id:
		# 事件触发时也需要重新检测目标
		var targets_to_apply: Array[Node] = _resolve_targets(context)
		for target_node in targets_to_apply:
			if is_instance_valid(target_node):
				_apply_all_effects_to_target(target_node, context)

## 统一游戏事件系统的回调
## 当任何游戏事件发生时，此方法会被调用
func _on_game_event_occurred(event_type: StringName, context: Dictionary) -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 简化：只检查事件类型是否匹配
	# 事件相关性应该由事件系统在发送时保证，或者在效果系统中过滤
	if status_data.can_trigger_on_event(event_type) or status_data.event_to_listen == event_type:
		handle_event(event_type, context)

## 刷新持续时间
func refresh_duration() -> void:
	if not is_instance_valid(_duration_timer):
		if status_data.duration > 0:
			_create_duration_timer()
		return
	_duration_timer.start(status_data.duration)

## 累加持续时间
func accumulate_duration() -> void:
	if not is_instance_valid(_duration_timer):
		if status_data.duration > 0:
			_create_duration_timer()
		return
	var remaining_time = _duration_timer.time_left
	var new_duration = remaining_time + status_data.duration
	_duration_timer.start(new_duration)

## 增加层数
func add_stack(amount: int = 1, is_refresh_duration: bool = true) -> void:
	if stacks < status_data.max_stacks:
		# --- 核心：重建效果 ---
		# 1. 移除所有旧的效果
		_remove_all_effects()

		# 2. 增加层数
		stacks = min(stacks + amount, status_data.max_stacks)

		# 3. 用 *新* 的层数，重新施加所有效果
		_apply_all_effects({})  # 'self.stacks' 已经是新值了
	
	# 4. 刷新持续时间
	if is_refresh_duration:
		refresh_duration()

## 创建周期性计时器（使用状态级别的 period）
func _create_periodic_timer() -> void:
	if not is_instance_valid(owner_component):
		push_error("GameplayStatusInstance: owner_component is not valid!")
		return
	
	# 如果已存在周期性计时器，先清理
	if is_instance_valid(_periodic_timer):
		_periodic_timer.stop()
		_periodic_timer.queue_free()
	
	_periodic_timer = Timer.new()
	_periodic_timer.wait_time = status_data.period
	_periodic_timer.timeout.connect(_on_periodic_effect)
	owner_component.add_child(_periodic_timer)
	_periodic_timer.start()

func _create_duration_timer() -> void:
	if not is_instance_valid(owner_component):
		return
	
	if status_data.duration <= 0:
		return
	
	_duration_timer = Timer.new()
	_duration_timer.name = "StatusTimer_%s" % status_data.status_id
	_duration_timer.one_shot = true
	_duration_timer.wait_time = status_data.duration
	_duration_timer.timeout.connect(_on_duration_timer_timeout)
	owner_component.add_child(_duration_timer)
	_duration_timer.start()

## 解析目标（根据配置的目标检测和筛选逻辑）
## [param] context: Dictionary 上下文信息
## [return] Array[Node] 要应用效果的目标列表
func _resolve_targets(context: Dictionary) -> Array[Node]:
	var target_entity = get_target_entity()
	if not is_instance_valid(target_entity):
		return []
	
	var targets_to_apply: Array[Node] = []
	
	# 1. 获取 hit_detector（优先使用 Status 配置的，如果没有则使用上下文传递的）
	var detector_to_use: HitDetectorBase = null
	if is_instance_valid(status_data.hit_detector):
		detector_to_use = status_data.hit_detector
	elif context.has("hit_detector") and is_instance_valid(context["hit_detector"]):
		detector_to_use = context["hit_detector"] as HitDetectorBase
	
	# 2. 检测目标（如果配置了 hit_detector）
	var detected_targets: Array[Node] = []
	if is_instance_valid(detector_to_use) and target_entity is Node3D:
		# 使用检测器检测目标
		detected_targets = detector_to_use.get_targets(
			target_entity as Node3D,
			context
		)
		
		# 使用策略进一步筛选目标（如果配置了）
		if is_instance_valid(status_data.targeting_strategy):
			var strategy_targets = status_data.targeting_strategy.resolve_targets(
				instigator,
				context.get("input_target", null),
				context
			)
			# 求交集（只保留同时出现在两个列表中的目标）
			var filtered_targets: Array[Node] = []
			for target in detected_targets:
				if target in strategy_targets:
					filtered_targets.append(target)
			detected_targets = filtered_targets

	# 3. 根据 target_mode 决定应用目标
	match status_data.target_mode:
		0:  # TargetApplicationMode.SELF
			# 只应用到自己
			targets_to_apply = [target_entity]
		1:  # TargetApplicationMode.DETECTED_TARGETS
			# 只应用到检测到的目标
			targets_to_apply = detected_targets.duplicate()
			
			# 如果没有检测到目标，尝试使用上下文中的 input_target
			if targets_to_apply.is_empty() and context.has("input_target"):
				var input_target = context["input_target"]
				if is_instance_valid(input_target):
					targets_to_apply = [input_target]
		2:  # TargetApplicationMode.BOTH
			# 同时应用到自己和检测到的目标
			targets_to_apply = detected_targets.duplicate()
			if target_entity not in targets_to_apply:
				targets_to_apply.append(target_entity)
	
	# 如果没有检测到目标且模式是 DETECTED_TARGETS，返回空列表
	if status_data.target_mode == 1 and targets_to_apply.is_empty():  # TargetApplicationMode.DETECTED_TARGETS
		return []
	
	# 如果最终没有目标，默认应用到自己（向后兼容）
	if targets_to_apply.is_empty():
		targets_to_apply = [target_entity]
	
	return targets_to_apply

## 对单个目标应用所有效果（统一入口，所有效果都克隆）
## [param] target: Node 目标实体
## [param] context: Dictionary 上下文信息
func _apply_all_effects_to_target(target: Node, context: Dictionary) -> void:
	if not is_instance_valid(target):
		return
	
	# 在context中添加stacks信息
	context["stacks"] = stacks
	
	# 统一克隆所有效果（参考技能系统，避免状态共享）
	for effect_template in status_data.effects:
		if not is_instance_valid(effect_template):
			continue
		
		# 克隆效果实例（避免状态共享）
		var effect_clone = effect_template.duplicate(true) as GameplayEffect
		if not is_instance_valid(effect_clone):
			continue
		
		# 应用效果
		effect_clone.apply(target, instigator, context)
		
		# 存储克隆，以便移除时调用 remove()
		# 注意：所有效果都存储，移除时统一调用 remove()
		stateful_effects.append(effect_clone)

## 应用所有效果（统一入口，所有效果都克隆）
## [已弃用] 使用 _apply_all_effects_to_target 替代
## 保留此方法以保持向后兼容
func _apply_all_effects(context: Dictionary) -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	_apply_all_effects_to_target(target, context)

## 移除所有效果
func _remove_all_effects() -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 迭代所有效果克隆，统一调用 remove()
	for effect_clone in stateful_effects:
		if is_instance_valid(effect_clone):
			effect_clone.remove(target, instigator)
	
	stateful_effects.clear()

## 计时器到期时，请求状态组件移除自己
func _on_duration_timer_timeout() -> void:
	if not is_instance_valid(owner_component):
		return
	
	# 通过接口调用remove_status方法（鸭子类型）
	if owner_component.has_method("remove_status"):
		owner_component.remove_status(get_id())

## 周期性效果到期时，应用所有效果
func _on_periodic_effect() -> void:
	var context = {"stacks": stacks}
	# 周期性效果也需要重新检测目标（因为目标可能已经改变）
	var targets_to_apply: Array[Node] = _resolve_targets(context)
	for target_node in targets_to_apply:
		if is_instance_valid(target_node):
			_apply_all_effects_to_target(target_node, context)

## 应用状态标签（标签系统集成）
func _apply_status_tags() -> void:
	var target = get_target_entity()
	if not is_instance_valid(target) or not is_instance_valid(status_data):
		return
	
	# 应用状态的所有标签
	for tag_id in status_data.tags:
		if tag_id != &"":
			TagManager.add_tag(target, tag_id)

## 移除状态标签（标签系统集成）
func _remove_status_tags() -> void:
	var target = get_target_entity()
	if not is_instance_valid(target) or not is_instance_valid(status_data):
		return
	
	# 移除状态的所有标签
	for tag_id in status_data.tags:
		if tag_id != &"":
			TagManager.remove_tag(target, tag_id)

## 执行状态 Cue（视觉反馈）
func _execute_status_cue() -> void:
	if not is_instance_valid(status_data) or not is_instance_valid(status_data.cue):
		return
	
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 执行 Cue（Manager 会处理挂点计算）
	GameplayCueManager.execute_cue(status_data.cue, target, {})

## 停止状态 Cue（清理视觉反馈）
func _stop_status_cue() -> void:
	if not is_instance_valid(status_data) or not is_instance_valid(status_data.cue):
		return
	
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 遍历所有 Cue 组件并停止持续效果
	for cue_component in status_data.cue.cues:
		if not is_instance_valid(cue_component):
			continue
		
		# 如果 Cue 组件实现了 stop 方法，调用它
		if cue_component.has_method("stop"):
			cue_component.stop(target)
