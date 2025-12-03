extends Resource
class_name GameplayAttributeSet

## 属性集合配置
## 格式：{ GameplayAttribute资源 : 初始值 float }
@export var attributes: Dictionary[GameplayAttribute, float] = {}

## 可扩展数值配置（可选）
## 格式：{ GameplayAttribute资源 : ScalableValue资源 }
## 如果属性在此字典中，则使用 ScalableValue 计算数值，忽略 attributes 中的固定值
@export var scalable_attributes: Dictionary[GameplayAttribute, ScalableValue] = {}

# --- 1. 实例化逻辑 ---
func instantiate_attributes() -> Dictionary:
	var instances = {}
	
	# 优先使用 scalable_attributes（如果存在）
	for attr_res in scalable_attributes:
		var scalable_val = scalable_attributes[attr_res]
		instances[attr_res.attribute_id] = GameplayAttributeInstance.new(attr_res, 0.0, scalable_val)
	
	# 处理固定值属性（如果不在 scalable_attributes 中）
	for attr_res in attributes:
		# 如果已经在 scalable_attributes 中处理过，跳过
		if scalable_attributes.has(attr_res):
			print("属性 %s 已经在 scalable_attributes 中处理过，跳过" % attr_res.attribute_id)
			continue
		var init_val = attributes[attr_res]
		instances[attr_res.attribute_id] = GameplayAttributeInstance.new(attr_res, init_val)
	
	return instances

# --- 2. 依赖处理接口 (核心) ---

# [钩子] 当组件初始化完毕，所有属性都创建好之后调用
# 用于计算初始的衍生属性
func resolve_dependencies(comp: GameplayAttributeComponent) -> void:
	pass

# [钩子] 当任何属性值发生变化时调用
# 用于实时更新衍生属性
func on_attribute_changed(comp: GameplayAttributeComponent, attr_id: StringName, new_val: float) -> void:
	pass
