extends Resource
class_name GameplayAttributeModifier

## 属性修改器
## 用于临时或永久修改属性值

enum ModifierType {
	ADD,      # 加法：直接加到基础值上 (Base + 10)
	MULTIPLY, # 乘法：基于加法后的值进行缩放 (Result * 1.5)
	OVERRIDE  # 覆盖：强制设置为某值 (很少用，但在某些特殊机制有效)
}

@export var attribute_id: StringName  ## 要修改的属性ID
@export var value: float  ## 修改值
@export var modifier_type: ModifierType  ## 修改类型
@export var source_id: StringName = &""  ## 来源ID（可选，用于批量移除）

func _init(
		p_attribute_id: StringName = &"", 
		p_value: float = 1.0, 
		p_modifier_type: ModifierType = ModifierType.MULTIPLY,
		p_source_id: StringName = &""
		) -> void:
	attribute_id = p_attribute_id
	value = p_value
	modifier_type = p_modifier_type
	source_id = p_source_id
