extends Resource
class_name GameplayAttributeSet

## 属性集合配置
## 格式：{ GameplayAttribute资源 : 初始值 float }
@export var attributes: Dictionary[GameplayAttribute, float] = {}

# --- 1. 实例化逻辑 ---
func instantiate_attributes() -> Dictionary:
    var instances = {}
    for attr_res in attributes:
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