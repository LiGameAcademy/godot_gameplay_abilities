extends RefCounted
class_name GameplayStatusInstance

## 状态实例
## 管理一个状态的生命周期，包括持续时间、层数、效果执行等

var status_data: GameplayStatusData
var owner_component: GameplayStatusComponent  ## 状态组件
var instigator: Node  ## 施加者
var stacks: int = 1

# 计时管理（由组件统一管理，这里只存储剩余时间）
var _remaining_duration: float = -1.0  ## 剩余持续时间，-1 表示永久，0 表示已过期
var _periodic_timer: float = 0.0  ## 周期性效果计时器（累积时间）

# 上下文缓存（用于移除时效果和周期性效果）
var _cached_context: Dictionary = {}  ## 保存应用时的上下文（用于周期性效果和移除时效果）
var _cue_instance: GameplayCue = null  ## 保存克隆的 Cue 实例（用于停止时清理）

## 状态完成信号
## 当状态完成时（瞬时状态立即完成，持续状态在移除时完成）发出此信号
## Ability 会订阅此信号来判断技能是否完成
signal status_completed(status_instance: GameplayStatusInstance)

func _init(
		p_data: GameplayStatusData = null, 
		p_owner_component: GameplayStatusComponent = null, 
		p_instigator: Node = null, 
		p_stacks: int = 1) -> void:
	status_data = p_data
	owner_component = p_owner_component
	instigator = p_instigator
	stacks = p_stacks
	
	# 初始化持续时间
	if is_instance_valid(status_data):
		_remaining_duration = status_data.duration if status_data.duration > 0 else -1.0

func get_id() -> StringName:
	if not is_instance_valid(status_data):
		return &""
	return status_data.status_id

func get_owner_component() -> Node:
	return owner_component

## 状态被施加时，应用所有效果
func apply(context: Dictionary = {}) -> void:
	# 保存上下文（用于周期性效果和移除时效果）
	_cached_context = context.duplicate()
	
	# 在 context 中添加 source_id（用于效果系统识别来源）
	if not context.has("source_id"):
		context["source_id"] = _get_source_instance_id()
	
	# 应用应用时效果
	_apply_effects(status_data.apply_effects, context)
	
	# 如果是瞬时效果（duration = 0），立即移除并发出完成信号
	if status_data.duration == 0.0:
		status_completed.emit(self)
		return
	
	# 初始化周期性计时器
	if status_data.period > 0.0:
		_periodic_timer = 0.0
	
	# 应用状态标签（标签系统集成）
	_apply_status_tags()
	
	# 执行状态 Cue（视觉反馈）
	_execute_status_cue()

## 状态被移除时，移除所有效果
func remove() -> void:
	# 1. 应用移除时效果（用于其他清理逻辑，如视觉效果、事件触发等）
	var remove_context = _cached_context.duplicate()
	remove_context["stacks"] = stacks
	# 确保 source_id 存在（用于效果系统识别来源）
	if not remove_context.has("source_id"):
		remove_context["source_id"] = _get_source_instance_id()
	_apply_effects(status_data.remove_effects, remove_context)
	_remove_effects(status_data.apply_effects, remove_context)
	
	# 2. 移除状态标签（标签系统集成）
	_remove_status_tags()
	
	# 3. 停止状态 Cue（清理视觉反馈）
	_stop_status_cue()
	
	# 4. 发出完成信号（持续状态在移除时完成）
	status_completed.emit(self)

## 处理事件（用于事件监听型效果）
## 此方法用于处理通过统一事件系统触发的事件
func handle_event(event_id: StringName, context: Dictionary) -> void:
	# 检查状态是否应该响应这个事件
	if not status_data.can_trigger_on_event(event_id):
		return
	
	# 应用事件触发型效果
	var event_context = context.duplicate()
	event_context["stacks"] = stacks
	# 确保使用状态实例的 source_id（如果事件触发效果应用了修改器，会在状态移除时自动清理）
	if not event_context.has("source_id"):
		event_context["source_id"] = _get_source_instance_id()
	_apply_effects(status_data.event_triggered_effects, event_context)

## 更新状态（由组件在 _process 中调用）
## [param] delta: float 帧时间
## [return] bool 是否已过期（需要移除）
func update(delta: float) -> bool:
	# 更新持续时间
	if _remaining_duration > 0:
		_remaining_duration -= delta
		if _remaining_duration <= 0:
			# 持续时间到期，返回 true 表示需要移除
			return true
	
	# 更新周期性效果计时器
	if status_data.period > 0.0 and not status_data.periodic_effects.is_empty():
		_periodic_timer += delta
		if _periodic_timer >= status_data.period:
			_periodic_timer = 0.0
			# 确保使用状态实例的 source_id（如果周期触发效果应用了修改器，会在状态移除时自动清理）
			var periodic_context = _cached_context.duplicate()
			periodic_context["source_id"] = _get_source_instance_id()
			_apply_effects(status_data.periodic_effects, periodic_context)
	
	return false

## 刷新持续时间
func refresh_duration() -> void:
	if status_data.duration > 0:
		_remaining_duration = status_data.duration

## 累加持续时间
func accumulate_duration() -> void:
	if status_data.duration > 0:
		if _remaining_duration < 0:
			_remaining_duration = status_data.duration
		else:
			_remaining_duration += status_data.duration

## 增加层数
## 注意：堆叠只影响移除生效、周期触发和事件触发的效果，不会重新触发应用时效果
## 属性修改器会重新应用（使用新层数），因为层数会影响修改器的值
func add_stack(amount: int = 1, is_refresh_duration: bool = true) -> void:
	if stacks < status_data.max_stacks:
		# 1. 移除旧的效果
		var context = _cached_context.duplicate()
		context["source_id"] = _get_source_instance_id()
		_apply_effects(status_data.remove_effects, context)

		# 2. 增加层数
		stacks = min(stacks + amount, status_data.max_stacks)

		# 3. 重新应用效果（使用新层数）
		context["stacks"] = stacks
		_apply_effects(status_data.apply_effects, context)
	
	# 4. 刷新持续时间
	if is_refresh_duration:
		refresh_duration()

## 应用效果
func _apply_effects(effects: Array[GameplayEffect], context: Dictionary) -> void:
	if not is_instance_valid(owner_component):
		return
	
	var target = owner_component.get_parent()
	if not is_instance_valid(target):
		return
	
	# 在context中添加stacks信息
	context["stacks"] = stacks
	
	# 应用所有效果
	for effect_template in effects:
		if not is_instance_valid(effect_template):
			continue
		
		# 克隆效果实例（避免状态共享）
		var effect_clone = effect_template.duplicate(true) as GameplayEffect
		if not is_instance_valid(effect_clone):
			continue
		
		# 应用效果（瞬时操作，不存储）
		effect_clone.apply(target, instigator, context)

## 移除效果
func _remove_effects(effects: Array[GameplayEffect], context: Dictionary) -> void:
	if not is_instance_valid(owner_component):
		return
	
	var target = owner_component.get_parent()
	if not is_instance_valid(target):
		return
	
	# 移除所有效果
	for effect_template in effects:
		if not is_instance_valid(effect_template):
			continue
		
		# 克隆效果实例（避免状态共享）
		var effect_clone = effect_template.duplicate(true) as GameplayEffect
		if not is_instance_valid(effect_clone):
			continue
		
		# 移除效果（瞬时操作，无状态）
		effect_clone.remove(target, instigator, context)

## 应用状态标签（标签系统集成）
func _apply_status_tags() -> void:
	if not is_instance_valid(owner_component) or not is_instance_valid(status_data):
		return
	
	# 应用状态的所有标签
	for tag_id in status_data.tags:
		if tag_id != &"":
			TagManager.add_tag(owner_component.get_parent(), tag_id)

## 移除状态标签（标签系统集成）
func _remove_status_tags() -> void:
	if not is_instance_valid(owner_component) or not is_instance_valid(status_data):
		return
	
	# 移除状态的所有标签
	for tag_id in status_data.tags:
		if tag_id != &"":
			TagManager.remove_tag(owner_component.get_parent(), tag_id)

## 执行状态 Cue（视觉反馈）
func _execute_status_cue() -> void:
	if not is_instance_valid(status_data) or not is_instance_valid(status_data.cue):
		return
	
	# 【关键】克隆 Cue 实例（避免直接修改配置数据）
	# 使用 deep 复制，确保所有 Cue 组件也被克隆
	_cue_instance = status_data.cue.duplicate(true) as GameplayCue
	if not is_instance_valid(_cue_instance):
		push_warning("GameplayStatusInstance: Failed to duplicate cue instance")
		return
	
	# 执行克隆的 Cue 实例（Manager 会处理挂点计算）
	GameplayCueManager.execute_cue(_cue_instance, owner_component.get_parent(), {})

## 停止状态 Cue（清理视觉反馈）
func _stop_status_cue() -> void:
	if not is_instance_valid(_cue_instance):
		# 如果没有保存的 Cue 实例，说明可能没有执行过 Cue，直接返回
		return
	
	# 【关键】使用克隆的 Cue 实例停止持续效果
	# 遍历所有 Cue 组件并停止持续效果
	for cue_component in _cue_instance.cues:
		if not is_instance_valid(cue_component):
			continue
		
		# 如果 Cue 组件实现了 stop 方法，调用它
		if cue_component.has_method("stop"):
			cue_component.stop(owner_component.get_parent())

func _get_source_instance_id() -> StringName:
	return "status." + str(get_instance_id())
