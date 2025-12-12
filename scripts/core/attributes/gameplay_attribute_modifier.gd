extends Resource
class_name GameplayAttributeModifier

## 属性修改器
## 用于临时或永久修改属性值

enum ModifierType {
    ADD,      # 加法：直接加到基础值上 (Base + 10)
    MULTIPLY, # 乘法：基于加法后的值进行缩放 (Result * 1.5)
    OVERRIDE  # 覆盖：强制设置为某值 (很少用，但在某些特殊机制有效)
}

@export var attribute_id: StringName
@export var value: float
@export var modifier_type: ModifierType
var source: Node = null 					## 来源（可选，用于追溯是谁施加的）

func _init(p_attribute_id: StringName = &"", p_value: float = 1.0, p_modifier_type: ModifierType = ModifierType.MULTIPLY) -> void:
	attribute_id = p_attribute_id
	value = p_value
	modifier_type = p_modifier_type
