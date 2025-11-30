extends Resource
class_name GameplayAttributeModifier

## 属性修改器
## 用于临时或永久修改属性值

enum ModifierType {
	ADDITIVE,				## 加法
	MULTIPLICATIVE,			## 乘法
	PERCENTAGE,				## 百分比
}

@export var attribute_id: StringName
@export var value: float
@export var modifier_type: ModifierType

func _init(p_attribute_id: StringName = &"", p_value: float = 1.0, p_modifier_type: ModifierType = ModifierType.MULTIPLICATIVE) -> void:
	attribute_id = p_attribute_id
	value = p_value
	modifier_type = p_modifier_type

