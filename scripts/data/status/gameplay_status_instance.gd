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
	# 1. 应用所有效果（立即生效的）
	# 注意：不区分"状态型效果"，所有效果都应用
	# 如果效果需要在特定时机触发，由效果自己决定（通过 delay 等）
	_apply_all_effects(context)
	
	# 2. 注册周期性效果（使用状态级别的 period）
	if status_data.period > 0.0:
		_create_periodic_timer()
	
	# 3. 连接到统一游戏事件系统
	# 如果状态配置了 trigger_on_events 或 event_to_listen，需要连接事件总线
	if not _is_connected_to_event_bus:
		var needs_event_bus = not status_data.trigger_on_events.is_empty() or status_data.event_to_listen != &""
		if needs_event_bus:
			AbilityEventBus.game_event_occurred.connect(_on_game_event_occurred)
			_is_connected_to_event_bus = true
	
	# 4. 应用状态标签（标签系统集成）
	_apply_status_tags()
	
	# 5. 执行状态 Cue（视觉反馈）
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
		# 应用所有效果
		_apply_all_effects(context)

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

## 应用所有效果（统一入口，所有效果都克隆）
func _apply_all_effects(context: Dictionary) -> void:
	var target = get_target_entity()
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
	_apply_all_effects(context)

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
