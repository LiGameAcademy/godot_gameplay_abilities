extends RefCounted
class_name GameplayAttributeInstance

## 属性实例
## 封装属性在某个实体上的实例，包含属性数据、当前值、修改器等

const ModifierType := GameplayAttributeModifier.ModifierType

## 属性数据（定义）
var attribute_data: GameplayAttribute = null

## 基础值
var base_value: float = 0.0

## 当前值（经过修改器计算后的最终值）
## 注意：这是计算后的值，通过 get_final_value() 获取
var _cached_final_value: float = 0.0

## 修改器列表
var modifiers: Array[GameplayAttributeModifier] = []

## 所属的属性组件
var owner: GameplayAttributeComponent = null

## 属性ID（快捷访问）
var attribute_id: StringName:
	get:
		if is_instance_valid(attribute_data):
			return attribute_data.attribute_id
		return &""

signal value_changed(old_value: float, new_value: float) ## 当前值变化信号
signal base_value_changed(old_value: float, new_value: float) ## 基础值变化信号

func _init(p_attribute_data: GameplayAttribute = null, p_base_value: float = 0.0, p_owner: GameplayAttributeComponent = null) -> void:
	attribute_data = p_attribute_data
	base_value = p_base_value
	owner = p_owner

## 获取最终值（经过所有修改器计算）
func get_final_value() -> float:
	return _calculate_final_value()

func _calculate_final_value() -> float:
	var value = base_value
	if modifiers.is_empty():
		return value
	
	# 属性修改器按照类型依次计算
	var modifier_type_map: Dictionary[ModifierType, float] = {
		ModifierType.ADDITIVE: 0.0,
		ModifierType.MULTIPLICATIVE: 1.0,
		ModifierType.PERCENTAGE: 1.0,
	}
	
	for modifier in modifiers:
		modifier_type_map[modifier.modifier_type] += modifier.value
	
	# 先计算乘法，再计算加法，最后计算百分比
	value = value * modifier_type_map[ModifierType.MULTIPLICATIVE] + modifier_type_map[ModifierType.ADDITIVE]
	value = value * (1.0 + modifier_type_map[ModifierType.PERCENTAGE])
	
	# 应用最小值和最大值限制
	if attribute_data:
		if attribute_data.min_value != -INF:
			value = max(value, attribute_data.min_value)
		if attribute_data.max_value != INF:
			value = min(value, attribute_data.max_value)
	
	_cached_final_value = value
	return value

## 设置基础值
func set_base_value(new_base_value: float, source: Variant = null) -> void:
	var old_base_value = base_value
	var old_final_value = _cached_final_value
	
	# 调用属性集的变化前钩子（如果存在）
	var actual_new_base_value = new_base_value
	if is_instance_valid(owner):
		var attribute_set = owner.get_attribute_set_for_instance(self)
		if is_instance_valid(attribute_set):
			var hook_result = attribute_set.pre_base_value_change(self, old_base_value, new_base_value, source)
			if hook_result is float:
				actual_new_base_value = hook_result
			elif hook_result != null:
				# 如果返回非float值，使用原值
				actual_new_base_value = new_base_value
	
	base_value = actual_new_base_value
	
	# 重新计算最终值
	var new_final_value = _calculate_final_value()
	
	# 调用属性集的变化后钩子（如果存在）
	if is_instance_valid(owner):
		var attribute_set = owner.get_attribute_set_for_instance(self)
		if is_instance_valid(attribute_set):
			attribute_set.post_final_value_changed(self, old_final_value, new_final_value, source)
	
	if old_final_value != new_final_value:
		value_changed.emit(old_final_value, new_final_value)
	
	base_value_changed.emit(old_base_value, actual_new_base_value)

## 添加修改器
func add_modifier(modifier: GameplayAttributeModifier) -> void:
	if modifier.attribute_id != attribute_id:
		push_error("GameplayAttributeInstance: Modifier attribute_id mismatch!")
		return
	
	modifiers.append(modifier)
	
	# 重新计算最终值
	var old_final_value = _cached_final_value
	var new_final_value = _calculate_final_value()
	if old_final_value != new_final_value:
		value_changed.emit(old_final_value, new_final_value)

## 移除修改器
func remove_modifier(modifier: GameplayAttributeModifier) -> void:
	var index = modifiers.find(modifier)
	if index == -1:
		push_error("GameplayAttributeInstance: Modifier not found!")
		return
	
	modifiers.remove_at(index)
	
	# 重新计算最终值
	var old_final_value = _cached_final_value
	var new_final_value = _calculate_final_value()
	if old_final_value != new_final_value:
		value_changed.emit(old_final_value, new_final_value)

## 获取最小值
func get_min_value() -> float:
	if is_instance_valid(attribute_data):
		return attribute_data.min_value
	return -INF

## 获取最大值
func get_max_value() -> float:
	if is_instance_valid(attribute_data):
		return attribute_data.max_value
	return INF

## 获取显示名称
func get_display_name() -> String:
	if is_instance_valid(attribute_data):
		return attribute_data.attribute_display_name
	return str(attribute_id)

## 获取描述
func get_description() -> String:
	if is_instance_valid(attribute_data):
		return attribute_data.attribute_description
	return ""
