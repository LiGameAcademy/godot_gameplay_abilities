extends RefCounted
class_name GameplayStatusInstance

## 状态实例
## 管理一个状态的生命周期，包括持续时间、层数、效果执行等

var status_data: GameplayStatusData
var owner_component: Node  ## 状态组件（采用鸭子类型，不依赖具体类型）
var instigator: Node  ## 施加者
var stacks: int = 1

# 智能处理器追踪已注册的监听器
var event_listeners: Dictionary = {}  # { "&damage_received": [GE1, GE2] }
var periodic_timers: Array[Timer] = []  # 追踪所有 Timer
var stateful_effects: Array[GameplayEffect] = []  # 追踪需要在 remove 时调用的效果

var _duration_timer: Timer = null  # 用于自动移除的计时器

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
	# 1. 施加状态型效果（立即生效，持续存在）
	_apply_all_stateful_effects(context)
	
	# 2. 注册周期和事件型效果
	for effect_template in status_data.effects:
		# 注意：这里我们迭代的是 *模板* (status_data.effects)
		if effect_template.period > 0.0:
			_create_timer(effect_template)
		elif effect_template.event_to_listen != &"":
			_add_event_listener(effect_template)

## 状态被移除时，移除所有效果
func remove() -> void:
	# 1. 停止持续时间计时器
	if is_instance_valid(_duration_timer):
		_duration_timer.stop()
		_duration_timer.queue_free()
		_duration_timer = null

	# 2. 移除所有状态型效果
	_remove_all_stateful_effects()

	# 3. 移除所有周期性计时器
	for timer in periodic_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	
	# 4. 清理数组
	periodic_timers.clear()
	event_listeners.clear()

## 处理事件（用于事件监听型效果）
func handle_event(event_id: StringName, context: Dictionary) -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	for effect in event_listeners.get(event_id, []):
		if is_instance_valid(effect):
			# 在context中添加stacks信息，供Effect使用
			context["stacks"] = stacks
			effect.apply(target, instigator, context)

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
		# --- 核心：重建状态型效果 ---
		# 1. 移除所有旧的状态型效果
		_remove_all_stateful_effects()

		# 2. 增加层数
		stacks = min(stacks + amount, status_data.max_stacks)

		# 3. 用 *新* 的层数，重新施加所有状态型效果
		_apply_all_stateful_effects({})  # 'self.stacks' 已经是新值了
	
	# 4. 刷新持续时间
	if is_refresh_duration:
		refresh_duration()

func _create_timer(effect: GameplayEffect) -> Timer:
	if not is_instance_valid(owner_component):
		push_error("GameplayStatusInstance: owner_component is not valid!")
		return null
	
	var timer = Timer.new()
	timer.wait_time = effect.period
	timer.timeout.connect(_on_periodic_effect.bind(effect))
	owner_component.add_child(timer)
	timer.start()
	periodic_timers.append(timer)
	return timer

func _add_event_listener(effect: GameplayEffect) -> void:
	if not event_listeners.has(effect.event_to_listen):
		event_listeners[effect.event_to_listen] = []
	event_listeners[effect.event_to_listen].append(effect)

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

## 施加所有状态型效果（立即生效，持续存在）
func _apply_all_stateful_effects(context: Dictionary) -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 迭代 *模板*
	for effect_template in status_data.effects:
		# 检查是否是"状态型"（不是周期性，不是事件监听型）
		if effect_template.period != 0.0 or not effect_template.event_to_listen.is_empty():
			continue
		
		# 创建克隆
		var effect_clone = effect_template.duplicate(true)
		# 在context中添加stacks信息
		context["stacks"] = stacks
		# 应用效果
		effect_clone.apply(target, instigator, context)
		# 存储克隆，以便移除
		stateful_effects.append(effect_clone)

## 移除所有状态型效果
func _remove_all_stateful_effects() -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 迭代 *克隆*
	for effect_clone in stateful_effects:
		if is_instance_valid(effect_clone):
			effect_clone.remove(target, instigator)
			effect_clone.free()  # 释放克隆
	
	stateful_effects.clear()

## 计时器到期时，请求状态组件移除自己
func _on_duration_timer_timeout() -> void:
	if not is_instance_valid(owner_component):
		return
	
	# 通过接口调用remove_status方法（鸭子类型）
	if owner_component.has_method("remove_status"):
		owner_component.remove_status(get_id())

## 周期性效果到期时，应用效果
func _on_periodic_effect(effect: GameplayEffect) -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	var context = {"stacks": stacks}
	if is_instance_valid(effect):
		effect.apply(target, instigator, context)
