extends Resource
class_name GameplayAttributeSet

## 属性集合配置
## 格式：{ GameplayAttribute资源 : 初始值 float }

@export var attributes: Dictionary[GameplayAttribute, float] = {}

## 实例化属性
## 将资源配置转换为运行时实例
## [return] Dictionary[StringName, GameplayAttributeInstance] 属性实例字典
func instantiate_attributes() -> Dictionary[StringName, GameplayAttributeInstance]:
	var instances : Dictionary[StringName, GameplayAttributeInstance] = {}
	for attr_res: GameplayAttribute in attributes:
		if not is_instance_valid(attr_res) or attr_res.attribute_id.strip_edges().is_empty():
			push_warning("GameplayAttributeSet: skipped a missing definition or blank attribute ID")
			continue
		var id: StringName = attr_res.attribute_id
		if instances.has(id):
			push_warning("GameplayAttributeSet: duplicate attribute ID '%s' was skipped" % id)
			continue
		var initial_value: float = attributes[attr_res]
		if not is_finite(initial_value):
			push_warning("GameplayAttributeSet: skipped non-finite initial value for '%s'" % id)
			continue
		instances[id] = GameplayAttributeInstance.new(attr_res, initial_value)
	return instances

## [钩子] 当组件初始化完毕，所有属性都创建好之后调用
## 用于计算初始的衍生属性（在后续章节中实现）
## [param] comp: GameplayAttributeComponent 属性组件
func resolve_dependencies(comp: GameplayAttributeComponent) -> void: pass

## [钩子] 当任何属性值发生变化时调用
## 用于实时更新衍生属性（在后续章节中实现）
## [param] comp: GameplayAttributeComponent 属性组件
## [param] attr_id: StringName 变化的属性ID
## [param] new_val: float 新值
func on_attribute_changed(comp: GameplayAttributeComponent, attr_id: StringName, new_val: float) -> void:pass
