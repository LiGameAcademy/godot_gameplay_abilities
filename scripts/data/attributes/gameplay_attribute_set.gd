extends Resource
class_name GameplayAttributeSet

## 属性集
## 配置属性，运行时初始化属性实例
## 例如单位可包含一级属性集（力量、体力、敏捷、智力）和二级属性集（攻击、防御、生命等）
## 通过钩子函数重写来实现属性依赖关系（例如1点力量转换为10点生命值）

## 获取属性数据（可选，用于编辑器配置）
## 格式：{ attribute_id: initial_value }
@export var attributes: Dictionary[GameplayAttribute, float] = {}

## 创建属性实例集合
## 返回该属性集的所有属性实例，由属性组件负责注册和管理
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
## [return] Dictionary[StringName, GameplayAttributeInstance] 属性实例字典
func create_instances(attribute_component: GameplayAttributeComponent) -> Dictionary[StringName, GameplayAttributeInstance]:
	var instances: Dictionary[StringName, GameplayAttributeInstance] = {}
	
	# 创建属性实例
	for attribute in attributes:
		var initial_value: float = attributes[attribute]
		# 创建属性实例
		var instance = GameplayAttributeInstance.new(attribute, initial_value, attribute_component)
		
		# 设置初始值（会自动计算最终值）
		instance.set_base_value(initial_value)
		
		# 添加到返回字典
		instances[attribute.attribute_id] = instance
	
	return instances

## 解析属性间的初始值依赖关系（公共接口）
## 由属性组件在所有实例创建完成后调用
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
func resolve_initial_value_dependencies(attribute_component: GameplayAttributeComponent) -> void:
	_on_resolve_initial_value_dependencies(attribute_component)

## 属性基础值变化前钩子（公共接口）
## 由属性组件在设置基础值之前调用
## [param] attribute_instance: GameplayAttributeInstance 属性实例
## [param] old_base_value: float 旧的基础值
## [param] proposed_new_base_value: float 提议的新基础值
## [param] source: Variant 变化来源（可选）
## [return] Variant 返回实际要设置的基础值（可以是修改后的值）
func pre_base_value_change(attribute_instance: GameplayAttributeInstance, old_base_value: float, proposed_new_base_value: float, source: Variant = null) -> Variant:
	return _pre_base_value_change(attribute_instance, old_base_value, proposed_new_base_value, source)

## 属性基础值变化前钩子（子类重写）
## 子类可重写此方法，在属性基础值变化前进行验证和修改
## [param] attribute_instance: GameplayAttributeInstance 属性实例
## [param] old_base_value: float 旧的基础值
## [param] proposed_new_base_value: float 提议的新基础值
## [param] source: Variant 变化来源（可选）
## [return] Variant 返回实际要设置的基础值（可以是修改后的值）
func _pre_base_value_change(attribute_instance: GameplayAttributeInstance, old_base_value: float, proposed_new_base_value: float, source: Variant = null) -> Variant:
	return proposed_new_base_value

## 属性最终值变化后钩子（公共接口）
## 由属性组件在最终值变化后调用
## [param] attribute_instance: GameplayAttributeInstance 属性实例
## [param] old_final_value: float 旧的最终值
## [param] new_final_value: float 新的最终值
## [param] source: Variant 变化来源（可选）
func post_final_value_changed(attribute_instance: GameplayAttributeInstance, old_final_value: float, new_final_value: float, source: Variant = null) -> void:
	_post_final_value_changed(attribute_instance, old_final_value, new_final_value, source)

## 属性最终值变化后钩子（子类重写）
## 子类可重写此方法，在属性最终值变化后进行处理
## [param] attribute_instance: GameplayAttributeInstance 属性实例
## [param] old_final_value: float 旧的最终值
## [param] new_final_value: float 新的最终值
## [param] source: Variant 变化来源（可选）
func _post_final_value_changed(attribute_instance: GameplayAttributeInstance, old_final_value: float, new_final_value: float, source: Variant = null) -> void:
	pass

## 当属性值变化时的回调（用于处理依赖关系）
## 用于处理属性依赖关系（例如：当力量变化时，更新生命值）
## [param] attribute_id: StringName 变化的属性ID
## [param] value: float 新的属性值
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
func post_attribute_value_changed(attribute_id: StringName, value: float, attribute_component: GameplayAttributeComponent) -> void:
	# 获取属性实例（如果存在）
	var attribute_instance = attribute_component.get_attribute_instance(attribute_id)
	if is_instance_valid(attribute_instance):
		# 使用新版API
		_on_attribute_dependency_changed(attribute_instance, attribute_component)

## 解析属性间的初始值依赖关系（子类重写）
## 子类应重写此方法，实现属性间的初始依赖（例如：根据一级属性计算二级属性初始值）
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
func _on_resolve_initial_value_dependencies(attribute_component: GameplayAttributeComponent) -> void: pass

## 当依赖的属性变化时，更新派生属性（新API：使用属性实例）
## 子类应重写此方法，实现属性依赖关系（例如：1点力量转换为10点生命值）
## [param] changed_attribute_instance: GameplayAttributeInstance 变化的属性实例
## [param] attribute_component: GameplayAttributeComponent 属性组件实例
func _on_attribute_dependency_changed(changed_attribute_instance: GameplayAttributeInstance, attribute_component: GameplayAttributeComponent) -> void: pass
