extends GameplayEffect
class_name GE_ModifyVital

## 修改 Vital

@export var vital_id: StringName = &""  ## Vital ID
@export var amount: float = 0.0  ## 修改量（正数为增加，负数为减少）
@export var vital_comp_name: StringName = &"GameplayVitalAttributeComponent"  ## Vital 组件名称

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var vital_comp : GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name)
	if not vital_comp:
		push_error("GE_ModifyVital: Target %s has no %s component" % [target.name, vital_comp_name])
		return
	
	# 直接从 context Dictionary 读取
	var stacks = context.get("stacks", 1)
	
	# 应用修改（正数为治疗，负数为伤害）
	vital_comp.modify_vital(vital_id, amount * stacks)
