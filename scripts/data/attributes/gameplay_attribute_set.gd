extends Resource
class_name GameplayAttributeSet

## 抽象属性集
## 配置属性，运行时初始化属性实例
## 例如单位可包含一级属性集（力量、体力、敏捷、智力）和二级属性集（攻击、防御、生命等）
## 通过钩子函数重写来实现属性依赖关系（例如1点力量转换为10点生命值）

## 属性配置
## 子类应重写此方法，返回该属性集包含的所有属性配置
## [return] Dictionary[StringName, Dictionary] 属性配置字典
##   格式：{ attribute_id: { "data": GameplayAttribute, "initial_value": float } }
func get_attribute_configs() -> Dictionary:
	# 默认实现：返回空字典
	# 子类应重写此方法，例如：
	# return {
	#     &"strength": { "data": strength_attr, "initial_value": 10.0 },
	#     &"constitution": { "data": constitution_attr, "initial_value": 8.0 }
	# }
	return {}

## 获取属性数据（可选，用于编辑器配置）
## 子类可以预定义属性的配置信息
@export var attribute_data_map: Dictionary[StringName, GameplayAttribute] = {}

## 获取属性初始值（可选，用于编辑器配置）
## 子类可以预定义属性的初始值
@export var attribute_initial_values: Dictionary[StringName, float] = {}

## 属性实例字典（运行时创建）
## 属性集管理自己的属性实例
var _instances: Dictionary[StringName, GameplayAttributeInstance] = {}

## 初始化属性集
## 在属性组件初始化时调用，创建和初始化属性实例
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
func initialize(attribute_component: GameplayAttributeComponent) -> void:
	# 获取属性配置
	var configs = get_attribute_configs()
	
	# 创建和初始化属性实例
	for attribute_id in configs:
		var config = configs[attribute_id]
		var attribute_data: GameplayAttribute = config.get("data", null)
		var initial_value: float = config.get("initial_value", 0.0)
		
		# 如果配置中没有数据，尝试从 attribute_data_map 获取
		if not attribute_data and attribute_data_map.has(attribute_id):
			attribute_data = attribute_data_map[attribute_id]
		
		# 如果配置中没有初始值，尝试从 attribute_initial_values 获取
		if initial_value == 0.0 and attribute_initial_values.has(attribute_id):
			initial_value = attribute_initial_values[attribute_id]
		
		# 创建属性实例
		var instance = GameplayAttributeInstance.new(attribute_data, initial_value, attribute_component)
		instance.value_changed.connect(_on_instance_value_changed.bind(attribute_id, attribute_component))
		
		# 存储到属性集的实例字典中
		_instances[attribute_id] = instance
		
		# 注册到属性组件（用于全局访问）
		attribute_component.register_attribute_instance(attribute_id, self)
		
		# 设置初始值（会自动计算最终值）
		instance.set_base_value(initial_value)
	
	# 解析初始值依赖关系
	_on_resolve_initial_value_dependencies(attribute_component)
	
	# 注册属性变化监听，用于处理依赖关系
	attribute_component.attribute_value_changed.connect(_on_attribute_value_changed.bind(attribute_component))

## 属性实例值变化回调（内部使用）
func _on_instance_value_changed(old_value: float, new_value: float, attribute_id: StringName, attribute_component: GameplayAttributeComponent) -> void:
	# 触发属性值变化事件
	attribute_component.attribute_value_changed.emit(attribute_id, new_value)

## 解析属性间的初始值依赖关系
## 子类应重写此方法，实现属性间的初始依赖（例如：CurrentHealth初始值 = MaxHealth初始值）
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
func _on_resolve_initial_value_dependencies(attribute_component: GameplayAttributeComponent) -> void:
	# 默认实现：空
	# 子类应重写此方法
	pass

## 在基础值变化前进行验证和修改（新API：使用属性实例）
## 子类可重写此方法，在属性基础值变化前进行拦截和修改
## [param] attribute_instance: GameplayAttributeInstance 属性实例
## [param] old_base_value: float 旧的基础值
## [param] proposed_new_base_value: float 提议的新基础值
## [param] source: Variant 变化来源（可选）
## [return] Variant 返回实际要设置的基础值（可以是修改后的值）
func _pre_base_value_change(attribute_instance: GameplayAttributeInstance, old_base_value: float, proposed_new_base_value: float, source: Variant = null) -> Variant:
	return proposed_new_base_value

## 在当前值变化后处理（新API：使用属性实例）
## 子类可重写此方法，在属性当前值变化后进行处理（如触发依赖更新、死亡检查等）
## [param] attribute_instance: GameplayAttributeInstance 属性实例
## [param] old_current_value: float 旧的当前值
## [param] new_current_value: float 新的当前值
## [param] source: Variant 变化来源（可选）
func _post_current_value_change(attribute_instance: GameplayAttributeInstance, old_current_value: float, new_current_value: float, source: Variant = null) -> void:
	pass

## 当属性值变化时的回调
## 用于处理属性依赖关系（例如：当力量变化时，更新生命值）
## [param] attribute_id: StringName 变化的属性ID
## [param] value: float 新的属性值
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
func _on_attribute_value_changed(attribute_id: StringName, value: float, attribute_component: GameplayAttributeComponent) -> void:
	# 获取属性实例（如果存在）
	var attribute_instance = attribute_component.get_attribute_instance(attribute_id)
	if is_instance_valid(attribute_instance):
		# 使用新版API
		_on_attribute_dependency_changed(attribute_instance, attribute_component)

## 当依赖的属性变化时，更新派生属性（新API：使用属性实例）
## 子类应重写此方法，实现属性依赖关系（例如：1点力量转换为10点生命值）
## [param] changed_attribute_instance: GameplayAttributeInstance 变化的属性实例
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
func _on_attribute_dependency_changed(changed_attribute_instance: GameplayAttributeInstance, attribute_component: GameplayAttributeComponent) -> void:
	pass

## 获取属性集中包含的所有属性ID
## [return] Array[StringName] 属性ID数组
func get_attribute_ids() -> Array[StringName]:
	var configs = get_attribute_configs()
	return configs.keys()

## 检查属性集是否包含指定属性
## [param] attribute_id: StringName 属性ID
## [return] bool 是否包含
func has_attribute(attribute_id: StringName) -> bool:
	var configs = get_attribute_configs()
	return configs.has(attribute_id)

## 获取属性数据
## [param] attribute_id: StringName 属性ID
## [return] GameplayAttribute 属性数据，如果不存在则返回null
func get_attribute_data(attribute_id: StringName) -> GameplayAttribute:
	var configs = get_attribute_configs()
	if configs.has(attribute_id):
		var config = configs[attribute_id]
		return config.get("data", null)
	return attribute_data_map.get(attribute_id, null)

## 获取属性实例
## [param] attribute_id: StringName 属性ID
## [return] GameplayAttributeInstance 属性实例，如果不存在则返回null
func get_attribute_instance(attribute_id: StringName) -> GameplayAttributeInstance:
	return _instances.get(attribute_id, null)

## 检查属性集是否包含指定属性的实例
## [param] attribute_id: StringName 属性ID
## [return] bool 是否包含
func has_attribute_instance(attribute_id: StringName) -> bool:
	return _instances.has(attribute_id)

## 获取所有属性实例
## [return] Dictionary[StringName, GameplayAttributeInstance] 属性实例字典
func get_all_instances() -> Dictionary[StringName, GameplayAttributeInstance]:
	return _instances.duplicate()

