extends Node
class_name GameplayAttributeComponent

## 属性组件
## 管理实体的所有游戏属性（采用鸭子类型设计，不继承基类）

const ModifierType := GameplayAttributeModifier.ModifierType

## 已注册的属性集
var _attribute_sets: Array[GameplayAttributeSet] = []

## 属性实例字典（由属性组件直接管理）
var _instances: Dictionary[StringName, GameplayAttributeInstance] = {}

## 属性ID到属性集的映射（用于快速查找属性集）
var _attribute_set_index: Dictionary[StringName, GameplayAttributeSet] = {}

signal attribute_value_changed(attribute_id: StringName, value: float)

## 使用属性集初始化（推荐方式）
## 属性集负责配置属性并创建属性实例
## [param] attribute_sets: Array[GameplayAttributeSet] 属性集数组
func initialize_with_attribute_sets(attribute_sets: Array[GameplayAttributeSet]) -> void:
	# 注册属性集
	_attribute_sets = attribute_sets.duplicate()
	
	# 从每个属性集创建实例并注册
	for attribute_set in _attribute_sets:
		if not is_instance_valid(attribute_set):
			continue
		
		# 从属性集获取实例集合
		var instances = attribute_set.create_instances(self)
		
		# 注册所有实例
		for attribute_id in instances:
			var atr_instance = instances[attribute_id]
			if not is_instance_valid(atr_instance):
				continue
			register_attribute_instance(attribute_id, atr_instance, attribute_set)

	# 解析初始值依赖关系（在所有实例创建完成后）
	for attribute_set in _attribute_sets:
		if is_instance_valid(attribute_set):
			# 解析初始值依赖关系
			attribute_set.resolve_initial_value_dependencies(self)
			# 注册属性变化监听，用于处理依赖关系
			if not attribute_value_changed.is_connected(attribute_set.post_attribute_value_changed):
				attribute_value_changed.connect(attribute_set.post_attribute_value_changed.bind(self))

## 注册属性实例（内部使用）
## [param] attribute_id: StringName 属性ID
## [param] instance: GameplayAttributeInstance 属性实例
## [param] attribute_set: GameplayAttributeSet 所属属性集
func register_attribute_instance(attribute_id: StringName, instance: GameplayAttributeInstance, attribute_set: GameplayAttributeSet) -> void:
	if _instances.has(attribute_id):
		push_warning("GameplayAttributeComponent: Attribute %s already exists, replacing..." % attribute_id)
	_instances[attribute_id] = instance
	_attribute_set_index[attribute_id] = attribute_set
	
	# 连接属性实例值变化信号
	if not instance.value_changed.is_connected(_on_instance_value_changed):
		instance.value_changed.connect(_on_instance_value_changed.bind(attribute_id))

## 属性实例值变化回调（内部使用）
func _on_instance_value_changed(old_value: float, new_value: float, attribute_id: StringName) -> void:
	# 触发属性值变化事件
	attribute_value_changed.emit(attribute_id, new_value)

func has_attribute(attribute_id: StringName) -> bool:
	return _instances.has(attribute_id)

## 获取属性实例
## [param] attribute_id: StringName 属性ID
## [return] GameplayAttributeInstance 属性实例，如果不存在则返回null
func get_attribute_instance(attribute_id: StringName) -> GameplayAttributeInstance:
	return _instances.get(attribute_id, null)

## 获取属性实例所属的属性集（内部使用）
## [param] instance: GameplayAttributeInstance 属性实例
## [return] GameplayAttributeSet 属性集，如果不存在则返回null
func get_attribute_set_for_instance(instance: GameplayAttributeInstance) -> GameplayAttributeSet:
	if not is_instance_valid(instance):
		return null
	var attribute_id = instance.attribute_id
	return _attribute_set_index.get(attribute_id, null)

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
