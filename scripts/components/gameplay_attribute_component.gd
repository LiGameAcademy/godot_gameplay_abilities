extends Node
class_name GameplayAttributeComponent

## 属性组件
## 管理实体的所有游戏属性（采用鸭子类型设计，不继承基类）

const ModifierType := GameplayAttributeModifier.ModifierType

## 已注册的属性集
## 属性实例由属性集管理，属性组件通过属性集访问
var _attribute_sets: Array[GameplayAttributeSet] = []

## 属性ID到属性集的映射（用于快速查找）
## 注意：属性实例实际存储在属性集中，这里只是属性集索引
var _attribute_set_index: Dictionary[StringName, GameplayAttributeSet] = {}

signal attribute_value_changed(attribute_id: StringName, value: float)

## 使用属性集初始化（推荐方式）
## 属性集负责配置属性并创建属性实例
## [param] attribute_sets: Array[GameplayAttributeSet] 属性集数组
func initialize_with_attribute_sets(attribute_sets: Array[GameplayAttributeSet]) -> void:
	# 注册属性集
	_attribute_sets = attribute_sets.duplicate()
	
	# 初始化每个属性集（属性集会创建和注册属性实例）
	for attribute_set in _attribute_sets:
		if is_instance_valid(attribute_set):
			attribute_set.initialize(self)

## 注册属性集索引（内部使用，由属性集调用）
## 用于快速查找属性所在的属性集
func register_attribute_instance(attribute_id: StringName, attribute_set: GameplayAttributeSet) -> void:
	if _attribute_set_index.has(attribute_id):
		push_warning("GameplayAttributeComponent: Attribute %s already exists in another set, replacing..." % attribute_id)
	_attribute_set_index[attribute_id] = attribute_set

func has_attribute(attribute_id: StringName) -> bool:
	return _attribute_set_index.has(attribute_id)

## 获取属性实例（通过属性集）
## [param] attribute_id: StringName 属性ID
## [return] GameplayAttributeInstance 属性实例，如果不存在则返回null
func get_attribute_instance(attribute_id: StringName) -> GameplayAttributeInstance:
	var attribute_set = _attribute_set_index.get(attribute_id, null)
	if attribute_set:
		return attribute_set.get_attribute_instance(attribute_id)
	return null

## 获取属性值（向后兼容API）
func get_value(attribute_id: StringName, default_value: float = 0.0) -> float:
	var instance = get_attribute_instance(attribute_id)
	if instance:
		return instance.get_final_value()
	push_error("Attribute not found: %s" % attribute_id)
	return default_value

## 设置属性值（向后兼容API）
func set_value(attribute_id: StringName, new_value: float) -> void:
	var instance = get_attribute_instance(attribute_id)
	if instance:
		instance.set_base_value(new_value)
	else:
		push_error("Attribute not found: %s" % attribute_id)

## 改变属性值
func change_value(attribute_id: StringName, delta: float) -> void:
	var instance = get_attribute_instance(attribute_id)
	if instance:
		instance.set_base_value(instance.base_value + delta)
	else:
		push_error("Attribute not found: %s" % attribute_id)

func get_attribute(attribute_id: StringName) -> GameplayAttribute:
	var instance = get_attribute_instance(attribute_id)
	if is_instance_valid(instance):
		return instance.attribute_data
	return null

func get_base_value(attribute_id: StringName) -> float:
	var instance = get_attribute_instance(attribute_id)
	if is_instance_valid(instance):
		return instance.base_value
	return 0.0

func add_modifier(attribute_modifier: GameplayAttributeModifier) -> void:
	var instance = get_attribute_instance(attribute_modifier.attribute_id)
	if is_instance_valid(instance):
		instance.add_modifier(attribute_modifier)
	else:
		push_error("Attribute not found: %s" % attribute_modifier.attribute_id)

func remove_modifier(attribute_modifier: GameplayAttributeModifier) -> void:
	var instance = get_attribute_instance(attribute_modifier.attribute_id)
	if is_instance_valid(instance):
		instance.remove_modifier(attribute_modifier)
	else:
		push_error("Modifier not found: %s" % attribute_modifier.attribute_id)
