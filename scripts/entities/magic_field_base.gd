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
## 周期性效果的目标选择模式（仅在 periodic_trigger_interval > 0 时有效）
var periodic_target_selection_mode: int = 2  # TargetSelectionMode.ALL
## 周期性效果的目标数量（-1 为全部，仅在 RANDOM 和 NEAREST 模式下有效）
var periodic_target_count: int = -1

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
## 返回：Array[Node] 当前区域内的所有有效目标
func _get_all_targets() -> Array[Node]:
	# 清理无效目标
	var current_targets = get_overlapping_bodies().filter(func(t): return is_instance_valid(t))
	return current_targets.duplicate()

## 【传感器接口】获取随机目标
## [param] count: int 要获取的目标数量（-1 为全部）
## [return] Array[Node] 随机目标列表
func _get_random_targets(count: int = -1) -> Array[Node]:
	var all_targets = _get_all_targets()
	
	if all_targets.is_empty():
		return []
	
	# 如果 count < 0 或 count >= 总数，返回所有目标
	if count < 0 or count >= all_targets.size():
		return all_targets
	
	# 随机选择指定数量的目标
	var selected: Array[Node] = []
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
func _get_nearest_targets(count: int = -1) -> Array[Node]:
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
	var sorted_targets: Array[Node] = []
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
		push_warning("")
		return
	
	# 根据配置选择目标
	var selected_targets: Array[Node] = []
	match periodic_target_selection_mode:
		0:  # RANDOM
			selected_targets = _get_random_targets(periodic_target_count)
		1:  # NEAREST
			selected_targets = _get_nearest_targets(periodic_target_count)
		2:  # ALL
			selected_targets = _get_all_targets()
	
	if selected_targets.is_empty():
		return
	
	# 对每个目标应用 payload_statuses
	for target in selected_targets:
		if not is_instance_valid(target):
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
