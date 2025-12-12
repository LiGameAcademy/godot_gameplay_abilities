extends Area3D
class_name MagicFieldBase

## 魔法场基类（区域效果载具）
## 职责：区域检测、弹头传递、生命周期管理
##
## 设计原则（载具-弹头模式）：
## - 魔法场是"载具"（Carrier），负责在指定位置持续检测目标
## - 魔法场不包含能力逻辑（如伤害计算），只负责将弹头传递给目标
## - 使用 Area3D 的事件驱动机制（body_entered/body_exited）维护目标列表
## - 周期性或事件触发时，将携带的弹头应用给目标

# ========== 运行时数据（由 Ability 注入）==========
## 施法者（用于过滤碰撞，避免击中自己，以及作为弹头的施加者）
var instigator: Node = null

# ========== 弹头舱（Payload Bay）==========
## 携带的状态列表（弹头）
## 当目标进入区域或周期性触发时，会将此列表中的状态应用给目标
var payload_statuses: Array[GameplayStatusData] = []

# ========== 内部状态 ==========
## 当前区域内的目标列表（维护状态句柄映射）
## 格式：{target: [status_id, ...]}
var _targets_in_area: Dictionary[Node, Array] = {}

# ========== 配置（由 MagicFieldData 注入）==========
## 持续时间（秒，-1 为永久）
var duration: float = 5.0
## 周期性触发间隔（秒）
## - 如果 > 0：魔法场会周期性触发，每次触发时对范围内的所有目标应用 payload_statuses
## - 如果 <= 0：单位进入范围时立即应用 payload_statuses，退出时移除
var periodic_trigger_interval: float = 0.0
## 目标选择模式（适用于所有触发模式）
## 当魔法场应用状态时，会根据此模式选择目标并应用 payload_statuses
var target_selection_mode: int = 2  # TargetSelectionMode.ALL
## 目标数量（-1 为全部，仅在 RANDOM 和 NEAREST 模式下有效）
var target_count: int = -1

# ========== 内部定时器 ==========
var _periodic_timer: Timer = null

func _ready() -> void:
	# 连接 Area3D 信号（事件驱动）
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 如果配置了持续时间，启动销毁计时器
	if duration > 0.0:
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(_on_duration_timeout)
	
	# 如果配置了周期性触发间隔，启动周期性触发定时器
	if periodic_trigger_interval > 0.0:
		_create_periodic_timer()
	#else:
		## 非周期性魔法场：立即检测并应用状态给所有已在范围内的目标
		## 使用 call_deferred 确保 Area3D 已经正确初始化并完成物理检测
		#call_deferred("_apply_to_existing_targets")

## 销毁魔法场（公共方法）
func destroy() -> void:
	# 移除所有目标身上的状态
	for target in _targets_in_area.keys():
		if is_instance_valid(target):
			_remove_payload_from_target(target)
	
	_targets_in_area.clear()
	
	# 停止周期性触发定时器
	if is_instance_valid(_periodic_timer):
		_periodic_timer.queue_free()
		_periodic_timer = null
	
	# 清理引用
	instigator = null
	payload_statuses.clear()
	_targets_in_area.clear()
	
	# 销毁节点
	queue_free()

## 【传感器接口】获取当前区域内的所有目标
## 返回：Array[Node3D] 当前区域内的所有有效目标（实体根节点）
## 
## 注意：使用 PhysicsServer3D 的同步查询，确保在创建时也能正确检测到目标
func _get_all_targets() -> Array[Node3D]:
	# 方法1：尝试使用 Area3D 的 overlapping 方法（事件驱动，更高效）
	var bodies = get_overlapping_bodies()
	var areas = get_overlapping_areas()
	
	# 如果检测到目标，使用事件驱动方法
	if not bodies.is_empty() or not areas.is_empty():
		return _get_targets_from_overlapping(bodies, areas)
	
	return []

## 从 overlapping 列表获取目标（事件驱动方法）
func _get_targets_from_overlapping(bodies: Array, areas: Array) -> Array[Node3D]:
	var all_colliders: Array[Node] = []
	var processed_entities: Dictionary = {}
	
	# 收集所有碰撞体
	for body in bodies:
		if is_instance_valid(body):
			all_colliders.append(body)
	
	for area in areas:
		if is_instance_valid(area):
			all_colliders.append(area)
	
	# 转换为实体并去重
	return _convert_colliders_to_entities(all_colliders, processed_entities)

## 将碰撞体列表转换为实体列表（去重）
func _convert_colliders_to_entities(all_colliders: Array[Node], processed_entities: Dictionary) -> Array[Node3D]:
	var valid_targets: Array[Node3D] = []
	
	for collider in all_colliders:
		# 使用 CombatUtils 将碰撞体转换为实体根节点
		var entity = CombatUtils.get_entity_from_collider(collider)
		if not is_instance_valid(entity):
			continue
		
		# 确保是 Node3D
		if not entity is Node3D:
			continue
		
		var entity_3d = entity as Node3D
		
		# 去重：使用 instance_id 避免同一实体被添加多次
		var entity_id = entity_3d.get_instance_id()
		if processed_entities.has(entity_id):
			continue
		
		processed_entities[entity_id] = true
		valid_targets.append(entity_3d)
	
	return valid_targets

## 【传感器接口】获取随机目标
## [param] count: int 要获取的目标数量（-1 为全部）
## [return] Array[Node] 随机目标列表
func _get_random_targets(count: int = -1) -> Array[Node3D]:
	var all_targets = _get_all_targets()
	
	if all_targets.is_empty():
		return []
	
	# 如果 count < 0 或 count >= 总数，返回所有目标
	if count < 0 or count >= all_targets.size():
		return all_targets
	
	# 随机选择指定数量的目标
	var selected: Array[Node3D] = []
	var available = all_targets.duplicate()
	
	for i in range(count):
		if available.is_empty():
			break
		
		var random_index = randi() % available.size()
		selected.append(available[random_index])
		available.remove_at(random_index)
	
	return selected

## 【传感器接口】获取指定数量的目标（按距离排序，最近的优先）
## [param] count: int 要获取的目标数量（-1 为全部）
## [return] Array[Node] 目标列表（按距离排序）
func _get_nearest_targets(count: int = -1) -> Array[Node3D]:
	var all_targets = _get_all_targets()
	
	if all_targets.is_empty():
		return []
	
	# 计算每个目标的距离
	var targets_with_distance: Array[Dictionary] = []
	for target in all_targets:
		if not target is Node3D:
			continue
		
		var target_3d = target as Node3D
		var distance = global_position.distance_to(target_3d.global_position)
		targets_with_distance.append({
			"target": target,
			"distance": distance
		})
	
	# 按距离排序
	targets_with_distance.sort_custom(func(a, b): return a["distance"] < b["distance"])
	
	# 提取目标列表
	var sorted_targets: Array[Node3D] = []
	for item in targets_with_distance:
		sorted_targets.append(item["target"])
	
	# 如果 count < 0 或 count >= 总数，返回所有目标
	if count < 0 or count >= sorted_targets.size():
		return sorted_targets
	
	# 返回前 count 个
	return sorted_targets.slice(0, count)

## 应用弹头（Payload）到目标
## [param] target: Node 目标实体
func _apply_payload_to_target(target: Node) -> void:
	if not is_instance_valid(target):
		push_warning("MagicFieldBase: Target is not valid, cannot apply payload to target %s" % target.name)
		return
	if not is_instance_valid(instigator):
		push_warning("MagicFieldBase: Instigator is not valid, cannot apply payload to target %s" % target.name)
		return
	
	# 准备上下文信息
	var context = {
		"field_position": global_position,
		"field": self
	}
	
	var status_handles: Array[StringName] = []
	
	# 应用状态
	for status_data in payload_statuses:
		if not is_instance_valid(status_data):
			push_warning("MagicFieldBase: Status data is not valid, cannot apply status %s" % status_data.status_id)
			continue
		
		# 获取目标的状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if is_instance_valid(status_comp):
			# 应用状态（状态系统会处理目标筛选和应用效果）
			var status_instance = status_comp.apply_status(status_data, instigator, 1, context)
			if is_instance_valid(status_instance):
				status_handles.append(status_data.status_id)
		else:
			push_warning("MagicFieldBase: Target %s has no GameplayStatusComponent, cannot apply status %s" % [target.name, status_data.status_id])

	# 记录状态句柄（用于离开时移除）
	if _targets_in_area.has(target):
		_targets_in_area[target] = status_handles

## 移除目标身上的弹头（Payload）
## [param] target: Node 目标实体
func _remove_payload_from_target(target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	# 获取状态句柄
	var status_handles = _targets_in_area.get(target, [])
	
	# 获取目标的状态组件
	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if is_instance_valid(status_comp):
		# 移除所有记录的状态
		for status_id in status_handles:
			status_comp.remove_status(status_id)
	else:
		push_warning("")

## 检查是否应该影响此目标
## [param] target: Node 目标实体
## [return] bool 是否应该影响
##
## 注意：此方法只做最基本的有效性检查
## 是否影响施法者、阵营判断等逻辑应该由 Effect 的过滤器（filters）来处理
## 这样设计的好处：
## 1. 治疗场可以影响施法者（给自己回血）
## 2. 增益场可以影响施法者（给自己加Buff）
## 3. 伤害场可以通过过滤器排除施法者（避免自伤）
func _should_affect(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	
	# 只检查目标是否有状态组件（魔法场需要应用状态）
	# 如果没有状态组件，无法应用效果，所以忽略
	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(status_comp):
		# 没有状态组件，无法应用效果，但这不是错误，只是跳过
		return false
	
	# 注意:
	# 是否影响施法者应该由 Effect 的过滤器（filters）来决定
	# 例如：
	# - 治疗场：Effect 的过滤器允许友军（包括自己）
	# - 伤害场：Effect 的过滤器只允许敌人（排除自己）
	
	return true

## 创建周期性触发定时器
func _create_periodic_timer() -> void:
	if periodic_trigger_interval <= 0.0:
		return
	
	_periodic_timer = Timer.new()
	_periodic_timer.name = "PeriodicTriggerTimer"
	_periodic_timer.wait_time = periodic_trigger_interval
	_periodic_timer.one_shot = false
	_periodic_timer.timeout.connect(_on_periodic_trigger)
	add_child(_periodic_timer)
	_periodic_timer.start()

## 应用状态给创建时已在范围内的目标（仅非周期性魔法场）
## 注意：此方法使用 call_deferred 调用，确保 Area3D 已经完成物理检测
func _apply_to_existing_targets() -> void:
	# 只处理非周期性魔法场（立即触发模式）
	if periodic_trigger_interval > 0.0:
		return
	
	# 等待一个物理帧，确保 Area3D 的物理检测已完成
	await get_tree().physics_frame
	
	# 根据目标选择模式获取目标
	var selected_targets = _select_targets_by_mode()
	
	# 调试信息
	print("MagicFieldBase: _apply_to_existing_targets - found %d targets (position: %s, mask: %d)" % [
		selected_targets.size(),
		global_position,
		collision_mask
	])
	
	if selected_targets.is_empty():
		return
	
	# 对每个目标应用状态
	for target in selected_targets:
		if not is_instance_valid(target):
			continue
		
		# 过滤检查
		if not _should_affect(target):
			continue
		
		# 应用状态
		_apply_payload_to_target(target)

## 根据目标选择模式获取目标列表
## [return] Array[Node] 根据配置选择的目标列表
func _select_targets_by_mode() -> Array[Node3D]:
	var selected_targets: Array[Node3D] = []
	match target_selection_mode:
		0:  # RANDOM
			selected_targets = _get_random_targets(target_count)
		1:  # NEAREST
			selected_targets = _get_nearest_targets(target_count)
		2:  # ALL
			selected_targets = _get_all_targets()
		_:
			push_warning("MagicFieldBase: Unknown target_selection_mode: %d, using ALL" % target_selection_mode)
			selected_targets = _get_all_targets()
	
	return selected_targets

## 目标进入区域
func _on_body_entered(body: Node3D) -> void:
	var target = body
	if not is_instance_valid(target):
		return
	
	# 过滤检查
	if not _should_affect(target):
		return
	
	# 根据触发模式决定是否立即应用状态
	if periodic_trigger_interval > 0.0:
		# 周期性触发模式：只维护目标列表，不立即应用状态
		# 状态会在周期性触发时应用
		_targets_in_area[target] = []
	else:
		# 立即触发模式：进入时立即应用状态
		_apply_payload_to_target(target)

## 目标离开区域
func _on_body_exited(body: Node3D) -> void:
	var target = body
	if not is_instance_valid(target):
		return
	
	if _targets_in_area.has(target):
		_remove_payload_from_target(target)
		_targets_in_area.erase(target)

## 周期性触发
## 当 periodic_trigger_interval > 0 时，此方法会周期性调用
## 对范围内的所有目标应用 payload_statuses
func _on_periodic_trigger() -> void:
	if not is_instance_valid(instigator):
		push_warning("MagicFieldBase: Instigator is not valid, cannot apply periodic effects.")
		return
	
	# 根据目标选择模式获取目标
	var selected_targets = _select_targets_by_mode()
	
	if selected_targets.is_empty():
		return
	
	# 对每个目标应用 payload_statuses
	for target in selected_targets:
		if not is_instance_valid(target):
			continue
		
		# 过滤检查
		if not _should_affect(target):
			continue
		
		# 应用弹头（Payload）
		_apply_payload_to_target(target)

## 持续时间到期
func _on_duration_timeout() -> void:
	# 移除所有目标身上的状态
	for target in _targets_in_area.keys():
		if is_instance_valid(target):
			_remove_payload_from_target(target)
	
	_targets_in_area.clear()
	
	# 销毁魔法场
	destroy()
