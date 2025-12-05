extends RefCounted
class_name CombatEventFactory

## 战斗事件工厂（实例类）
## 根据事件类型创建对应的事件对象，符合开闭原则
## 作为AbilityEventBus的成员变量使用，而非静态类

## 事件类型到事件类的映射
var _event_class_map: Dictionary[StringName, Callable] = {}

func _init() -> void:
	_initialize_event_map()

## 初始化事件类映射
func _initialize_event_map() -> void:
	if not _event_class_map.is_empty():
		return
	
	# 注册所有事件类型
	_register_event(&"damage_received", _create_damage_received_event)
	_register_event(&"damage_dealt", _create_damage_dealt_event)
	_register_event(&"entity_died", _create_entity_died_event)
	_register_event(&"healing_applied", _create_healing_applied_event)
	_register_event(&"health_restored", _create_health_restored_event)
	_register_event(&"attribute_changed", _create_attribute_changed_event)
	_register_event(&"ability_completed", _create_ability_completed_event)
	_register_event(&"ability_failed", _create_ability_failed_event)
	_register_event(&"ability_learned", _create_ability_learned_event)
	_register_event(&"ability_forgotten", _create_ability_forgotten_event)
	_register_event(&"ability_cooldown_ready", _create_ability_cooldown_ready_event)
	_register_event(&"status_applied", _create_status_applied_event)
	_register_event(&"status_removed", _create_status_removed_event)

## 注册事件类型
## [param] event_type: StringName 事件类型
## [param] factory_func: Callable 创建事件对象的函数
func register_event(event_type: StringName, factory_func: Callable) -> void:
	_initialize_event_map()
	_event_class_map[event_type] = factory_func

## 创建事件对象
## [param] event_type: StringName 事件类型
## [param] context: Dictionary 事件上下文
## [return] CombatEvent 事件对象，如果类型未注册则返回GenericEvent
func create_event(event_type: StringName, context: Dictionary) -> CombatEvent:
	_initialize_event_map()
	
	var factory_func = _event_class_map.get(event_type)
	if factory_func:
		return factory_func.call(context)
	
	# 未注册的事件类型，返回通用事件
	return GenericEvent.new(event_type, context)

## 注册事件（内部方法）
func _register_event(event_type: StringName, factory_func: Callable) -> void:
	_event_class_map[event_type] = factory_func

# ========== 事件创建函数 ==========

func _create_damage_received_event(context: Dictionary) -> CombatEvent:
	return DamageReceivedEvent.from_dict(context)

func _create_damage_dealt_event(context: Dictionary) -> CombatEvent:
	return DamageDealtEvent.from_dict(context)

func _create_entity_died_event(context: Dictionary) -> CombatEvent:
	return EntityDiedEvent.new(context)

func _create_healing_applied_event(context: Dictionary) -> CombatEvent:
	return HealingAppliedEvent.new(context)

func _create_health_restored_event(context: Dictionary) -> CombatEvent:
	return HealthRestoredEvent.new(context)

func _create_attribute_changed_event(context: Dictionary) -> CombatEvent:
	return AttributeChangedEvent.new(context)

func _create_ability_completed_event(context: Dictionary) -> CombatEvent:
	return AbilityCompletedEvent.new(context)

func _create_ability_failed_event(context: Dictionary) -> CombatEvent:
	return AbilityFailedEvent.new(context)

func _create_ability_learned_event(context: Dictionary) -> CombatEvent:
	return AbilityLearnedEvent.new(context)

func _create_ability_forgotten_event(context: Dictionary) -> CombatEvent:
	return AbilityForgottenEvent.new(context)

func _create_ability_cooldown_ready_event(context: Dictionary) -> CombatEvent:
	return AbilityCooldownReadyEvent.new(context)

func _create_status_applied_event(context: Dictionary) -> CombatEvent:
	return StatusAppliedEvent.new(context)

func _create_status_removed_event(context: Dictionary) -> CombatEvent:
	return StatusRemovedEvent.new(context)

