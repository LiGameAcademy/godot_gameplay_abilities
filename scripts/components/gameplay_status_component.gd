extends Node
class_name GameplayStatusComponent

## 状态组件（采用鸭子类型设计，不继承基类）
## 管理实体的所有状态（Buff/Debuff）

var _active_statuses: Dictionary[StringName, GameplayStatusInstance] = {}
var _health_comp: Node = null  ## 用于订阅伤害事件（采用鸭子类型）

signal status_applied(status_id: StringName, instance: GameplayStatusInstance)
signal status_removed(status_id: StringName)
signal status_stacked(status_id: StringName, new_stacks: int)

func _ready() -> void:
	# 使用鸭子类型查询HealthComponent
	_health_comp = CombatSystem.get_component_by_interface(get_parent(), "HealthComponent")
	
	if is_instance_valid(_health_comp):
		# 订阅 HealthComponent 的伤害事件（使用鸭子类型检查信号）
		if _health_comp.has_signal("damage_received") and not _health_comp.damage_received.is_connected(_on_damage_received):
			_health_comp.damage_received.connect(_on_damage_received)

## 添加状态
## [param] gsd: GameplayStatusData 状态数据
## [param] instigator: Node 施加者
## [param] stacks: int 初始层数
## [param] context: Dictionary 上下文信息
func apply_status(gsd: GameplayStatusData, instigator: Node, stacks: int = 1, context: Dictionary = {}) -> void:
	if not is_instance_valid(gsd):
		push_error("GameplayStatusComponent: GameplayStatusData is not valid!")
		return
	
	var status_id = gsd.status_id
	
	# 【核心堆叠逻辑】
	if _active_statuses.has(status_id):
		var existing_instance = _active_statuses[status_id]
		
		# 根据 GSD 中的策略进行处理
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
	else:
		# 【新实例逻辑】
		var instance = GameplayStatusInstance.new(gsd, self, instigator, stacks)
		_active_statuses[gsd.status_id] = instance
		instance.apply(context)
		status_applied.emit(status_id, instance)
		
		# 触发统一游戏事件：status_applied
		CombatEventBus.trigger_game_event(&"status_applied", {
			"entity": get_parent(),
			"status_id": status_id
		})
		
		# 同时发送细粒度事件（向后兼容）
		CombatEventBus.emit_status_applied(get_parent(), status_id)

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
	CombatEventBus.trigger_game_event(&"status_removed", {
		"entity": get_parent(),
		"status_id": status_id
	})
	
	# 同时发送细粒度事件（向后兼容）
	CombatEventBus.emit_status_removed(get_parent(), status_id)

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
