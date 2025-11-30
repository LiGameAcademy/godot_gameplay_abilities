extends Node

## 技能事件总线（单例）
## 提供全局事件通讯机制，实现组件间的解耦
## 支持统一的事件触发接口和细粒度的事件信号

# ========== 事件工厂 ==========
## 事件工厂实例（作为单例成员变量，而非静态类）
var event_factory: CombatEventFactory

# ========== 外部事件系统集成 ==========
## 外部事件总线引用（可选，用于订阅外部系统事件）
var external_event_bus: Node = null
## 外部事件订阅映射（event_name -> signal_connection）
var _external_subscriptions: Dictionary[StringName, Array] = {}

# ========== 统一游戏事件系统 ==========
## 统一游戏事件信号
## 所有游戏事件都通过此信号统一触发，状态系统可以配置监听多个事件类型
## [param] event_type: StringName 事件类型，如 "damage_received", "turn_start", "ability_activated" 等
## [param] context: Dictionary 事件上下文，包含事件相关的所有信息
signal game_event_occurred(event_type: StringName, context: Dictionary)

# ========== 细粒度事件信号（向后兼容）==========
# 伤害相关事件
signal damage_dealt(instigator: Node, target: Node, damage_info: DamageInfo, final_damage: float)
signal damage_received(target: Node, damage_info: DamageInfo)
signal entity_died(entity: Node, instigator: Node)

# 治疗相关事件
signal healing_applied(target: Node, amount: float)
signal health_restored(entity: Node)

# 属性相关事件
signal attribute_changed(entity: Node, attribute_id: StringName, new_value: float)

# 技能相关事件
signal ability_activated(entity: Node, ability_id: StringName)
signal ability_failed(entity: Node, ability_id: StringName, reason: String)
signal ability_learned(entity: Node, ability_id: StringName)
signal ability_forgotten(entity: Node, ability_id: StringName)
signal ability_cooldown_ready(entity: Node, ability_id: StringName)

# 状态相关事件
signal status_applied(entity: Node, status_id: StringName)
signal status_removed(entity: Node, status_id: StringName)


# ========== 初始化 ==========

func _ready() -> void:
	# 初始化事件工厂
	event_factory = CombatEventFactory.new()
	
	# 自动查找外部事件总线（可选）
	_auto_discover_external_event_bus()

## 发送伤害事件
func emit_damage_dealt(instigator: Node, target: Node, damage_info: DamageInfo, final_damage: float) -> void:
	damage_dealt.emit(instigator, target, damage_info, final_damage)

## 发送实体死亡事件
func emit_entity_died(entity: Node, instigator: Node) -> void:
	entity_died.emit(entity, instigator)

## 发送治疗事件
func emit_healing_applied(target: Node, amount: float) -> void:
	healing_applied.emit(target, amount)

## 发送属性变化事件
func emit_attribute_changed(entity: Node, attribute_id: StringName, new_value: float) -> void:
	attribute_changed.emit(entity, attribute_id, new_value)

## 发送技能激活事件
func emit_ability_activated(entity: Node, ability_id: StringName) -> void:
	ability_activated.emit(entity, ability_id)

## 发送技能失败事件
func emit_ability_failed(entity: Node, ability_id: StringName, reason: String) -> void:
	ability_failed.emit(entity, ability_id, reason)

## 发送技能学习事件
func emit_ability_learned(entity: Node, ability_id: StringName) -> void:
	ability_learned.emit(entity, ability_id)

## 发送技能遗忘事件
func emit_ability_forgotten(entity: Node, ability_id: StringName) -> void:
	ability_forgotten.emit(entity, ability_id)

## 发送技能冷却就绪事件
func emit_ability_cooldown_ready(entity: Node, ability_id: StringName) -> void:
	ability_cooldown_ready.emit(entity, ability_id)

## 发送状态应用事件
func emit_status_applied(entity: Node, status_id: StringName) -> void:
	status_applied.emit(entity, status_id)

## 发送状态移除事件
func emit_status_removed(entity: Node, status_id: StringName) -> void:
	status_removed.emit(entity, status_id)

# ========== 统一游戏事件系统接口 ==========

## 触发游戏事件（统一接口 - 支持两种方式）
## 方式1：直接传入事件实例（推荐，类型安全，无需工厂）
## 方式2：传入事件类型和上下文字典（向后兼容，使用工厂模式）
## 
## [param] event_or_type: CombatEvent | StringName 事件实例或事件类型
## [param] context: Dictionary | Variant 事件上下文（方式2时使用，可选）
## 
## 使用示例：
## ```gdscript
## # 方式1：直接传入事件实例（推荐，类型安全）
## var ctx = DamageReceivedContext.new(source, target, damage_info)
## var event = DamageReceivedEvent.new(ctx)
## AbilityEventBus.trigger_game_event(event)
## 
## # 方式2：传入类型和字典（向后兼容）
## AbilityEventBus.trigger_game_event(&"damage_received", {
##     "source": source, 
##     "target": target, 
##     "damage_info": damage_info
## })
## ```
func trigger_game_event(event_or_type: Variant, context: Variant = {}) -> void:
	var event: CombatEvent = null
	var event_type: StringName = &""
	var context_dict: Dictionary = {}
	
	# 判断是方式1（传入事件实例）还是方式2（传入类型+字典）
	if event_or_type is CombatEvent:
		# 方式1：直接使用传入的事件实例（推荐）
		event = event_or_type
		event_type = event.event_type
		context_dict = event.get_context()
	else:
		# 方式2：使用工厂模式创建事件（向后兼容）
		event_type = event_or_type as StringName
		if context is Dictionary:
			context_dict = context
		else:
			context_dict = {}
		event = event_factory.create_event(event_type, context_dict)
	
	# 发出统一游戏事件信号
	game_event_occurred.emit(event_type, context_dict)
	
	# 利用多态触发细粒度信号（向后兼容）
	if event:
		# 使用call方法调用，避免类型推断问题
		if event.has_method("emit_gameplay_signal"):
			event.call("emit_gameplay_signal", self)

	# 等待一帧，确保事件处理完成
	await get_tree().process_frame

# ========== 外部事件系统集成 ==========

## 设置外部事件总线
## [param] event_bus: Node 外部事件总线节点
func set_external_event_bus(event_bus: Node) -> void:
	external_event_bus = event_bus

## 订阅外部事件
## [param] event_name: StringName 外部事件名称
## [param] callback: Callable 回调函数
## [param] signal_name: StringName 信号名称（如果与事件名称不同）
func subscribe_to_external_event(event_name: StringName, callback: Callable, signal_name: StringName = &"") -> bool:
	if not external_event_bus:
		push_warning("AbilityEventBus: External event bus not set. Call set_external_event_bus() first.")
		return false
	
	var sig_name = signal_name if not signal_name.is_empty() else event_name
	
	if not external_event_bus.has_signal(sig_name):
		push_warning("AbilityEventBus: External event bus does not have signal: " + sig_name)
		return false
	
	var connection = external_event_bus.connect(sig_name, callback)
	if connection == OK:
		if not _external_subscriptions.has(event_name):
			_external_subscriptions[event_name] = []
		_external_subscriptions[event_name].append({
			"signal_name": sig_name,
			"callback": callback
		})
		return true
	
	return false

## 取消订阅外部事件
## [param] event_name: StringName 外部事件名称
func unsubscribe_from_external_event(event_name: StringName) -> void:
	if not _external_subscriptions.has(event_name):
		return
	
	if not external_event_bus:
		_external_subscriptions.erase(event_name)
		return
	
	for subscription in _external_subscriptions[event_name]:
		if external_event_bus.is_connected(subscription.signal_name, subscription.callback):
			external_event_bus.disconnect(subscription.signal_name, subscription.callback)
	
	_external_subscriptions.erase(event_name)

## 自动发现外部事件总线（查找常见的命名）
func _auto_discover_external_event_bus() -> void:
	var common_names = [
		"/root/GameEventBus",
		"/root/EventBus",
		"/root/GameManager",
		"/root/EventSystem"
	]
	
	for path in common_names:
		var node = get_node_or_null(path)
		if not is_instance_valid(node) :
			continue
		if node.has_method("trigger_event") or node.has_signal("game_event"):
			external_event_bus = node
			print("AbilityEventBus: Auto-discovered external event bus at: " + path)
			return
