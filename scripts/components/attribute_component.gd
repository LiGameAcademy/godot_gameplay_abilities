extends Node
class_name AttributeComponent

## 属性组件
## 管理实体的所有游戏属性（采用鸭子类型设计，不继承基类）

const ModifierType := GameplayAttributeModifier.ModifierType

var _current_values: Dictionary[StringName, float] = {}
var _attribute_map : Dictionary[StringName, GameplayAttribute] = {}
var _modifiers: Dictionary[StringName, Array] = {}

signal attribute_value_changed(attribute_id: StringName, value: float)

## 初始化属性
## [param] attributes: Dictionary[StringName, float] 属性ID和初始值的字典
## [param] attribute_data_map: Dictionary[StringName, GameplayAttribute] 属性数据映射（可选，用于获取属性配置）
func initialize_attributes(attributes: Dictionary[StringName, float], attribute_data_map: Dictionary = {}) -> void:
	for attribute_id in attributes:
		_current_values[attribute_id] = attributes[attribute_id]
		if attribute_data_map.has(attribute_id):
			_attribute_map[attribute_id] = attribute_data_map[attribute_id]

func has_attribute(attribute_id: StringName) -> bool:
	return _current_values.has(attribute_id)

## 获取属性值
func get_value(attribute_id: StringName, default_value: float = 0.0) -> float:
	if not _current_values.has(attribute_id):
		push_error("Attribute not found: %s" % attribute_id)
		return default_value
	return _current_values.get(attribute_id, default_value)

## 设置属性值
func set_value(attribute_id: StringName, new_value: float) -> void:
	if _current_values.has(attribute_id):
		var attribute: GameplayAttribute = _attribute_map.get(attribute_id, null)
		if attribute != null:
			if attribute.min_value != -INF and new_value < attribute.min_value:
				push_warning("Attribute value is less than min value: %s" % attribute.attribute_id)
			if attribute.max_value != INF and new_value > attribute.max_value:
				push_warning("Attribute value is greater than max value: %s" % attribute.attribute_id)
			_current_values[attribute_id] = clamp(new_value, attribute.min_value, attribute.max_value)
		else:
			_current_values[attribute_id] = new_value
		attribute_value_changed.emit(attribute_id, _current_values[attribute_id])
	else:
		push_error("Attribute not found: %s" % attribute_id)

## 改变属性值
func change_value(attribute_id: StringName, delta: float) -> void:
	if _current_values.has(attribute_id):
		var new_value = _current_values[attribute_id] + delta
		set_value(attribute_id, new_value)
	else:
		push_error("Attribute not found: %s" % attribute_id)

func get_attribute(attribute_id: StringName) -> GameplayAttribute:
	return _attribute_map.get(attribute_id, null)

func get_base_value(attribute_id: StringName) -> float:
	var attribute: GameplayAttribute = get_attribute(attribute_id)
	if attribute == null:
		return _current_values.get(attribute_id, 0.0)
	return attribute.base_value

func add_modifier(attribute_modifier: GameplayAttributeModifier) -> void:
	if not _current_values.has(attribute_modifier.attribute_id):
		push_error("Attribute not found: %s" % attribute_modifier.attribute_id)
		return
	if not _modifiers.has(attribute_modifier.attribute_id):
		_modifiers[attribute_modifier.attribute_id] = []
	_modifiers[attribute_modifier.attribute_id].append(attribute_modifier)
	_current_values[attribute_modifier.attribute_id] = _calculate_attribute_value(attribute_modifier.attribute_id)
	attribute_value_changed.emit(attribute_modifier.attribute_id, _current_values[attribute_modifier.attribute_id])

func remove_modifier(attribute_modifier: GameplayAttributeModifier) -> void:
	if not _modifiers.has(attribute_modifier.attribute_id):
		push_error("Modifier not found: %s" % attribute_modifier.attribute_id)
		return
	_modifiers[attribute_modifier.attribute_id].erase(attribute_modifier)
	if _modifiers[attribute_modifier.attribute_id].is_empty():
		_modifiers.erase(attribute_modifier.attribute_id)
	_current_values[attribute_modifier.attribute_id] = _calculate_attribute_value(attribute_modifier.attribute_id)
	attribute_value_changed.emit(attribute_modifier.attribute_id, _current_values[attribute_modifier.attribute_id])

func _calculate_attribute_value(attribute_id: StringName) -> float:
	var value = get_base_value(attribute_id)
	if not _modifiers.has(attribute_id):
		return value
	# 属性修改器按照类型依次计算
	var _modifier_type_map: Dictionary[ModifierType, float] = {
		ModifierType.ADDITIVE: 0.0,
		ModifierType.MULTIPLICATIVE: 1.0,
		ModifierType.PERCENTAGE: 1.0,
	}
	for modifier in _modifiers[attribute_id]:
		_modifier_type_map[modifier.modifier_type] += modifier.value

	# 先计算乘法，再计算加法，最后计算百分比
	value = value * _modifier_type_map[ModifierType.MULTIPLICATIVE] + _modifier_type_map[ModifierType.ADDITIVE]
	value = value * (1.0 + _modifier_type_map[ModifierType.PERCENTAGE])

	return value

