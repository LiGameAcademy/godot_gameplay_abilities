extends Node
class_name GameplayStatusComponent

## 状态组件（采用鸭子类型设计，不继承基类）
## 管理实体的所有状态（Buff/Debuff）

const GROUP_NAME := "StatusEntities"

var _active_statuses: Dictionary[StringName, GameplayStatusInstance] = {}
var _health_comp: Node = null  ## 用于订阅伤害事件（采用鸭子类型）

signal status_applied(status_id: StringName, instance: GameplayStatusInstance)
signal status_removed(status_id: StringName)
signal status_stacked(status_id: StringName, new_stacks: int)

func _ready() -> void:
	# 将父节点（实体）添加到状态实体组，方便调试面板等工具查询
	var entity = get_parent()
	if is_instance_valid(entity) and not entity.is_in_group(GROUP_NAME):
		entity.add_to_group(GROUP_NAME)
	
	# 使用鸭子类型查询HealthComponent
	_health_comp = GameplayAbilitySystem.get_component_by_interface(get_parent(), "HealthComponent")
	
	if is_instance_valid(_health_comp):
		# 订阅 HealthComponent 的伤害事件（使用鸭子类型检查信号）
		if _health_comp.has_signal("damage_received") and not _health_comp.damage_received.is_connected(_on_damage_received):
			_health_comp.damage_received.connect(_on_damage_received)

## 添加状态
## [param] gsd: GameplayStatusData 状态数据
## [param] instigator: Node 施加者
## [param] stacks: int 初始层数
## [param] context: Dictionary 上下文信息
## [return] GameplayStatusInstance 返回状态实例（如果应用成功），否则返回 null
func apply_status(gsd: GameplayStatusData, instigator: Node, stacks: int = 1, context: Dictionary = {}) -> GameplayStatusInstance:
	if not is_instance_valid(gsd):
		push_error("GameplayStatusComponent: GameplayStatusData is not valid!")
		return null
	
	var status_id: StringName = gsd.status_id
	
	# 状态 ID 为空：允许应用，但不参与记录/堆叠/优先级比较
	if status_id.is_empty():
		return _create_and_apply_new_status_instance(gsd, instigator, stacks, context)
	
	# 1. 优先级检查（可能会移除旧状态或直接拒绝新状态）
	if not _handle_priority_for_existing_status(status_id, gsd):
		return null
	
	# 2. 堆叠逻辑：如果已经有同 ID 的状态，根据 stacking_policy 处理
	if _apply_stacking_for_existing_status(status_id, gsd, stacks):
		# 对已有实例做了刷新/叠加等处理，不需要创建新实例
		return null
	
	# 3. 创建并应用新的状态实例
	return _create_and_apply_new_status_instance(gsd, instigator, stacks, context)

## 处理已有状态的优先级比较
## [return] bool 是否允许继续后续流程（false 表示应直接拒绝新状态）
func _handle_priority_for_existing_status(status_id: StringName, gsd: GameplayStatusData) -> bool:
	if not _active_statuses.has(status_id):
		return true
	
	var existing_instance: GameplayStatusInstance = _active_statuses[status_id]
	if not is_instance_valid(existing_instance) or not is_instance_valid(existing_instance.status_data):
		# 旧实例异常时，直接移除并允许新状态进入
		_active_statuses.erase(status_id)
		return true
	
	var existing_priority: int = existing_instance.status_data.priority
	
	if gsd.priority > existing_priority:
		# 新状态优先级更高，移除旧状态
		remove_status(status_id)
		return true
	elif gsd.priority < existing_priority:
		# 旧状态优先级更高，忽略新状态
		return false
	
	# 优先级相同，继续后续堆叠逻辑
	return true

## 对已有状态应用堆叠策略
## [return] bool 是否已经对已有实例进行了处理（true 表示已处理完毕，无需创建新实例）
func _apply_stacking_for_existing_status(status_id: StringName, gsd: GameplayStatusData, stacks: int) -> bool:
	if not _active_statuses.has(status_id):
		return false
	
	var existing_instance: GameplayStatusInstance = _active_statuses[status_id]
	if not is_instance_valid(existing_instance):
		_active_statuses.erase(status_id)
		return false
	
	match gsd.stacking_policy:
		GameplayStatusData.StackingPolicy.REFRESH_DURATION:
			existing_instance.refresh_duration()
		GameplayStatusData.StackingPolicy.STACK_INTENSITY:
			existing_instance.add_stack(stacks, true)
			status_stacked.emit(status_id, existing_instance.stacks)
		GameplayStatusData.StackingPolicy.ACCUMULATE_DURATION:
			existing_instance.accumulate_duration()
		GameplayStatusData.StackingPolicy.IGNORE:
			# 忽略，不处理
			pass
	
	return true

## 创建并应用新的状态实例
## - 对于有 ID 的状态：根据 duration 决定是否写入 _active_statuses
## - 对于 ID 为空的状态：不会写入 _active_statuses，仅执行一次性效果
func _create_and_apply_new_status_instance(
		gsd: GameplayStatusData,
		instigator: Node,
		stacks: int,
		context: Dictionary) -> GameplayStatusInstance:
	var instance := GameplayStatusInstance.new(gsd, self, instigator, stacks)
	var status_id: StringName = gsd.status_id
	
	# 仅当状态 ID 非空且有持续时间时才记录到激活状态表
	if not status_id.is_empty() and gsd.duration != 0.0:
		_active_statuses[status_id] = instance
	
	# 先应用状态（执行效果）
	instance.apply(context)
	
	# 发信号和事件（即便 ID 为空，也允许外部根据实例做自定义逻辑）
	status_applied.emit(status_id, instance)
	
	# 触发统一游戏事件：status_applied
	AbilityEventBus.trigger_game_event(&"status_applied", {
		"entity": get_parent(),
		"status_id": status_id
	})
	
	# 同时发送细粒度事件（向后兼容）
	AbilityEventBus.emit_status_applied(get_parent(), status_id)
	
	return instance

## 移除状态
## [param] status_id: StringName 状态ID
func remove_status(status_id: StringName) -> void:
	var instance = _active_statuses.get(status_id)
	if not is_instance_valid(instance): 
		return
	
	_active_statuses.erase(status_id)
	instance.remove()
	status_removed.emit(status_id)
	
	# 触发统一游戏事件：status_removed
	AbilityEventBus.trigger_game_event(&"status_removed", {
		"entity": get_parent(),
		"status_id": status_id
	})
	
	# 同时发送细粒度事件（向后兼容）
	AbilityEventBus.emit_status_removed(get_parent(), status_id)

## 移除所有匹配标签的状态
## [param] tags_to_remove: Array[StringName] 要移除的标签数组
func remove_statuses_by_tags(tags_to_remove: Array[StringName]) -> void:
	for status_id in _active_statuses.keys():
		var instance = _active_statuses.get(status_id)
		if not is_instance_valid(instance): 
			continue
		
		var gsd = instance.status_data
		
		# 检查这个Status的tags是否与我们要移除的tags有交集
		for tag in gsd.tags:
			if tags_to_remove.has(tag):
				# 找到了一个匹配！移除这个Status
				remove_status(status_id)
				break  # 移动到下一个状态实例

## 获取所有激活的状态
func get_active_statuses() -> Array[GameplayStatusInstance]:
	return _active_statuses.values()

## 获取指定状态
## [param] status_id: StringName 状态ID
func get_status(status_id: StringName) -> GameplayStatusInstance:
	return _active_statuses.get(status_id, null)

## 检查是否有指定状态
## [param] status_id: StringName 状态ID
func has_status(status_id: StringName) -> bool:
	return _active_statuses.has(status_id)

## 获取随机状态
## [param] is_debuff: bool 是否只获取Debuff
func get_random_status(is_debuff: bool = false) -> GameplayStatusInstance:
	if _active_statuses.size() == 0:
		return null
	
	var statuses: Array[GameplayStatusInstance] = []
	for status in _active_statuses.values():
		if status.status_data.is_debuff == is_debuff:
			statuses.append(status)
	
	if statuses.size() == 0:
		return null
	
	return statuses.pick_random()

## 处理事件（供外部调用，触发事件监听型效果）
## [param] event_id: StringName 事件ID
## [param] context: Dictionary 上下文信息
func handle_event(event_id: StringName, context: Dictionary) -> void:
	for instance in _active_statuses.values():
		if is_instance_valid(instance):
			instance.handle_event(event_id, context)

## 订阅 HealthComponent 的伤害事件
## 注意：此方法仍然保留用于向后兼容，但状态现在主要通过统一事件系统响应
func _on_damage_received(damage_info: DamageInfo) -> void:
	var context = {"damage_info": damage_info}
	handle_event(&"damage_received", context)
