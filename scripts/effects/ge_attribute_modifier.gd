@tool
extends GameplayEffect
class_name GE_AttributeModifier

## 属性修改器效果（状态型）
## 在效果应用时添加属性修改器，移除时删除

@export var attribute_modifier: GameplayAttributeModifier
@export var base_value: float = 0.0
@export var value_per_stack: float = 0.0  ## 每层增加的值

var _applied_modifier: GameplayAttributeModifier  ## 存储已应用的修改器，用于移除

func _apply(target: Node, _instigator: Node, context: AbilityContext) -> void:
	# 使用鸭子类型查询组件
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayAttributeComponent")
	if not attr_comp:
		push_error("GE_AttributeModifier: Target %s has no GameplayAttributeComponent." % target.name)
		return

	if not is_instance_valid(attribute_modifier):
		push_error("GE_AttributeModifier: 'attribute_modifier' 不能为空！")
		return
	
	# 创建修改器的副本
	_applied_modifier = attribute_modifier.duplicate()

	# 根据层数计算最终值（如果context中有stacks信息）
	var stacks = context.custom_data.get("stacks", 1)
	if value_per_stack != 0.0:
		# (stacks - 1) 意味着第1层是 base_value，第2层是 base + value_per_stack
		_applied_modifier.value = base_value + (value_per_stack * (stacks - 1))
	else:
		# 否则，使用模板中定义的固定值
		_applied_modifier.value = base_value

	# 应用修改器
	attr_comp.add_modifier(_applied_modifier)

func _remove(target: Node, _instigator: Node) -> void:
	# 使用鸭子类型查询组件
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayAttributeComponent")
	if not attr_comp:
		# 目标可能已经销毁，这很正常
		return
	
	if not is_instance_valid(_applied_modifier):
		push_error("GE_AttributeModifier: 'applied_modifier' 不能为空！")
		return

	attr_comp.remove_modifier(_applied_modifier)

func _get_description() -> String:
	if not is_instance_valid(attribute_modifier):
		return "Apply attribute modifier\n"
	return "Apply attribute modifier %s to target\n" % [attribute_modifier.attribute_id]

