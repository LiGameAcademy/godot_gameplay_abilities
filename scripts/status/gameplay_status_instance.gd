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
var _initial_context: Dictionary = {}  # 保存应用时的上下文（用于周期性效果）
var _cue_instance: GameplayCue = null  # 保存克隆的 Cue 实例（用于停止时清理）
var _applied_attribute_modifiers: Array[GameplayAttributeModifier] = []  # 存储已应用的属性修改器（用于移除时清理）

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
	# 保存初始上下文（用于周期性效果，如魔法场引用）
	_initial_context = context.duplicate()
	
	# 获取状态被应用到的实体（状态持有者）
	var status_holder = get_target_entity()
	if not is_instance_valid(status_holder):
		return
	
	# 【关键】获取效果应用的目标列表
	# 如果配置了 targeting_strategy，使用策略选择目标
	# 否则，直接应用到状态持有者（默认行为）
	var effect_targets: Array[Node] = _get_effect_targets(status_holder, context)
	
	# 为所有目标应用效果
	for target in effect_targets:
		if is_instance_valid(target):
			_apply_all_effects_to_target(target, context)
	
	# 3. 如果是瞬时效果（duration = 0），立即移除并发出完成信号
	if status_data.duration == 0.0:
		status_completed.emit(self)
		return
	
	# 4. 注册周期性效果（使用状态级别的 period）
	# 注意：只有当配置了 periodic_effects 且 period > 0 时才创建周期性计时器
	if status_data.period > 0.0 and not status_data.periodic_effects.is_empty():
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
	
	# 7. 注册属性修改器（如果配置了）
	_register_attribute_modifiers()
	
	# 8. 注册技能行为修改器（如果配置了）
	_register_ability_modifiers()
	
	# 9. 执行状态 Cue（视觉反馈）
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
	
	# 6. 移除属性修改器（清理属性修改）
	_unregister_attribute_modifiers()
	
	# 7. 移除技能行为修改器（清理修改器）
	_unregister_ability_modifiers()
	
	# 8. 停止状态 Cue（清理视觉反馈）
	_stop_status_cue()
	
	# 8. 发出完成信号（持续状态在移除时完成）
	status_completed.emit(self)

## 处理事件（用于事件监听型效果）
## 此方法用于处理通过统一事件系统触发的事件
func handle_event(event_id: StringName, context: Dictionary) -> void:
	var status_holder = get_target_entity()
	if not is_instance_valid(status_holder):
		return
	
	# 检查状态是否应该响应这个事件
	if not status_data.can_trigger_on_event(event_id):
		return
	
	# 检查是否是状态级别的事件监听
	if status_data.event_to_listen == event_id:
		# 【关键】获取效果应用的目标列表（支持目标选择策略）
		var effect_targets: Array[Node] = _get_effect_targets(status_holder, context)
		
		# 为所有目标应用效果
		for target in effect_targets:
			if is_instance_valid(target):
				_apply_all_effects_to_target(target, context)

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
## 注意：只重新应用需要存储的效果（属性修改器等），不重新触发瞬时效果
func add_stack(amount: int = 1, is_refresh_duration: bool = true) -> void:
	if stacks < status_data.max_stacks:
		# --- 核心：重建需要存储的效果（属性修改器等）---
		# 1. 移除所有旧的需要存储的效果
		_remove_all_effects()
		
		# 2. 移除旧的属性修改器（使用旧层数）
		_unregister_attribute_modifiers()

		# 3. 增加层数
		stacks = min(stacks + amount, status_data.max_stacks)

		# 4. 重新注册属性修改器（使用新层数）
		_register_attribute_modifiers()

		# 5. 用 *新* 的层数，重新施加所有效果
		# 注意：虽然会重新触发所有效果，但这是必要的，因为其他状态型效果需要重新应用
		# 瞬时效果（如伤害）虽然会被重新触发，但这是可以接受的权衡
		# 如果希望避免重新触发瞬时效果，应该在 GameplayStatusData 中将它们分离到 instant_effects
		var target_entity = get_target_entity()
		if is_instance_valid(target_entity):
			var context = {"stacks": stacks}
			# 重新应用所有效果（包括瞬时效果）
			# 这是为了确保其他需要存储的效果能够正确更新
			_apply_all_effects_to_target(target_entity, context, false)
	
	# 6. 刷新持续时间
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

## 获取效果应用的目标列表（支持目标选择策略）
## [param] status_holder: Node 状态持有者（状态被应用到的实体）
## [param] context: Dictionary 上下文信息
## [return] Array[Node] 目标列表
func _get_effect_targets(status_holder: Node, context: Dictionary) -> Array[Node]:
	# 如果配置了 targeting_strategy，使用策略选择目标
	if is_instance_valid(status_data.targeting_strategy):
		# 准备策略上下文
		var strategy_context = context.duplicate()
		strategy_context["status_holder"] = status_holder
		strategy_context["status_id"] = status_data.status_id
		
		# 使用策略解析目标
		# 注意：instigator 作为施法者，status_holder 作为 input_target
		var targets = status_data.targeting_strategy.resolve_targets(instigator, status_holder, strategy_context)
		
		# 如果策略返回了目标，使用它们
		if not targets.is_empty():
			return targets
	
	# 默认：直接应用到状态持有者
	return [status_holder]

## 对单个目标应用所有效果（状态应用时触发）
## 区分需要存储的效果（属性修改器）和不需要存储的效果（瞬时效果）
## [param] target: Node 目标实体
## [param] context: Dictionary 上下文信息
## [param] only_stateful: bool 是否只处理需要存储的效果（用于 add_stack 时只处理属性修改器）
func _apply_all_effects_to_target(target: Node, context: Dictionary, only_stateful: bool = false) -> void:
	if not is_instance_valid(target):
		return
	
	# 在context中添加stacks信息
	context["stacks"] = stacks
	
	# 只处理状态应用时的效果（effects），不包括周期性效果（periodic_effects）
	for effect_template in status_data.effects:
		if not is_instance_valid(effect_template):
			continue
		
		# 如果 only_stateful=true，只处理需要存储的效果（有 _remove 实现的效果）
		# 检查效果是否有 _remove 方法的实现（通过检查方法是否存在）
		if only_stateful:
			# 检查效果类是否有 _remove 方法的实现
			# 注意：GDScript 中，如果子类没有重写 _remove，基类的 _remove 是空的
			# 我们需要通过其他方式判断，比如检查效果类型或使用标志
			# 这里我们假设所有需要存储的效果都会在 apply 时设置某种标志
			# 或者我们可以检查效果是否有特定的方法或属性
			# 暂时：如果 only_stateful=true，我们仍然应用所有效果，但只存储那些有实际 remove 逻辑的
			# 实际上，更好的方案是：在 GameplayStatusData 中区分 effects 和 instant_effects
			# 但为了保持向后兼容，我们暂时保持当前逻辑
			pass
		
		# 克隆效果实例（避免状态共享）
		var effect_clone = effect_template.duplicate(true) as GameplayEffect
		if not is_instance_valid(effect_clone):
			continue
		
		# 应用效果
		effect_clone.apply(target, instigator, context)
		
		# 存储效果到 stateful_effects（用于移除时清理）
		# 注意：所有效果都存储，但在 add_stack 时，我们只重新应用需要存储的效果
		# 实际上，瞬时效果（如伤害）虽然被存储，但它们的 remove 方法是空的，所以不会有副作用
		if not only_stateful:
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
	
	owner_component.remove_status(get_id())

## 周期性效果到期时，应用周期性效果
## 注意：周期性效果不会存储到 stateful_effects，每次触发时直接应用
func _on_periodic_effect() -> void:
	# 合并初始上下文和当前上下文（保留魔法场引用等关键信息）
	var context = _initial_context.duplicate()
	context["stacks"] = stacks
	
	# 获取状态持有者
	var status_holder = get_target_entity()
	if not is_instance_valid(status_holder):
		return
	
	# 【关键】获取效果应用的目标列表（支持目标选择策略）
	var effect_targets: Array[Node] = _get_effect_targets(status_holder, context)
	
	# 只处理周期性效果（periodic_effects），不处理应用时效果（effects）
	for effect_template in status_data.periodic_effects:
		if not is_instance_valid(effect_template):
			continue
		
		# 克隆效果实例（避免状态共享）
		var effect_clone = effect_template.duplicate(true) as GameplayEffect
		if not is_instance_valid(effect_clone):
			continue
		
		# 为所有目标应用周期性效果
		for target in effect_targets:
			if is_instance_valid(target):
				# 直接应用，不存储到 stateful_effects
				effect_clone.apply(target, instigator, context)

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
	
	# 【关键】克隆 Cue 实例（避免直接修改配置数据）
	# 使用 deep 复制，确保所有 Cue 组件也被克隆
	_cue_instance = status_data.cue.duplicate(true) as GameplayCue
	if not is_instance_valid(_cue_instance):
		push_warning("GameplayStatusInstance: Failed to duplicate cue instance")
		return
	
	# 执行克隆的 Cue 实例（Manager 会处理挂点计算）
	GameplayCueManager.execute_cue(_cue_instance, target, {})

## 停止状态 Cue（清理视觉反馈）
func _stop_status_cue() -> void:
	if not is_instance_valid(_cue_instance):
		# 如果没有保存的 Cue 实例，说明可能没有执行过 Cue，直接返回
		return
	
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 【关键】使用克隆的 Cue 实例停止持续效果
	# 遍历所有 Cue 组件并停止持续效果
	for cue_component in _cue_instance.cues:
		if not is_instance_valid(cue_component):
			continue
		
		# 如果 Cue 组件实现了 stop 方法，调用它
		if cue_component.has_method("stop"):
			cue_component.stop(target)

## 注册属性修改器（状态应用时调用）
func _register_attribute_modifiers() -> void:
	if not is_instance_valid(status_data) or status_data.attribute_modifiers.is_empty():
		return
	
	# 通过 owner_component 获取属性组件（降低耦合）
	if not is_instance_valid(owner_component) or not owner_component.has_method("get_attribute_component"):
		return
	
	var attr_comp = owner_component.get_attribute_component()
	if not is_instance_valid(attr_comp):
		# 如果没有 AttributeComponent，静默失败（不是所有实体都需要属性）
		return
	
	# 注册所有属性修改器
	for mod_template in status_data.attribute_modifiers:
		if not is_instance_valid(mod_template):
			continue
		
		# 创建修改器的副本（避免修改模板）
		var mod = mod_template.duplicate() as GameplayAttributeModifier
		if not is_instance_valid(mod):
			continue
		
		# 根据层数计算最终值（如果配置了 value_per_stack）
		if status_data.attribute_modifier_value_per_stack != 0.0:
			# (stacks - 1) 意味着第1层是 base_value，第2层是 base + value_per_stack
			mod.value = status_data.attribute_modifier_base_value + (status_data.attribute_modifier_value_per_stack * (stacks - 1))
		elif status_data.attribute_modifier_base_value != 0.0:
			# 如果只配置了 base_value，使用 base_value
			mod.value = status_data.attribute_modifier_base_value
		# 否则，使用模板中定义的固定值
		
		# 应用修改器
		attr_comp.add_modifier(mod)
		
		# 存储已应用的修改器（用于移除时清理）
		if not _applied_attribute_modifiers:
			_applied_attribute_modifiers = []
		_applied_attribute_modifiers.append(mod)

## 移除属性修改器（状态移除时调用）
func _unregister_attribute_modifiers() -> void:
	if not is_instance_valid(status_data) or not _applied_attribute_modifiers:
		return
	
	# 通过 owner_component 获取属性组件（降低耦合）
	if not is_instance_valid(owner_component) or not owner_component.has_method("get_attribute_component"):
		return
	
	var attr_comp = owner_component.get_attribute_component()
	if not is_instance_valid(attr_comp):
		return
	
	# 移除所有已应用的属性修改器
	for mod in _applied_attribute_modifiers:
		if is_instance_valid(mod):
			attr_comp.remove_modifier(mod)
	
	_applied_attribute_modifiers.clear()

## 注册技能行为修改器（状态应用时调用）
func _register_ability_modifiers() -> void:
	if not is_instance_valid(status_data) or status_data.ability_modifiers.is_empty():
		return
	
	# 通过 owner_component 获取修改器组件（降低耦合）
	if not is_instance_valid(owner_component) or not owner_component.has_method("get_modifier_component"):
		return
	
	var modifier_comp = owner_component.get_modifier_component()
	if not is_instance_valid(modifier_comp):
		# 如果没有 ModifierComponent，静默失败（不是所有实体都需要修改器）
		return
	
	# 为每个修改器设置来源（使用状态 ID 作为来源标识）
	var source_id = "status." + status_data.status_id
	
	# 注册所有修改器
	for mod in status_data.ability_modifiers:
		if is_instance_valid(mod):
			modifier_comp.add_modifier(mod, source_id)

## 移除技能行为修改器（状态移除时调用）
func _unregister_ability_modifiers() -> void:
	if not is_instance_valid(status_data):
		return
	
	# 通过 owner_component 获取修改器组件（降低耦合）
	if not is_instance_valid(owner_component) or not owner_component.has_method("get_modifier_component"):
		return
	
	var modifier_comp = owner_component.get_modifier_component()
	if not is_instance_valid(modifier_comp):
		return
	
	# 使用来源标识批量移除（更高效）
	var source_id = "status." + status_data.status_id
	modifier_comp.remove_modifiers_by_source(source_id)
	
	# 清理 Cue 实例引用
	_cue_instance = null

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
