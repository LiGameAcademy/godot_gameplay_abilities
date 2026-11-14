extends GameplayEffect
class_name GE_AttributeModifier

@export var modifiers: Array[GameplayAttributeModifier] = []
## Source for batch removal. Context takes precedence. Without an explicit source,
## application and removal must use the same effect instance.
@export var source_id: StringName = &""
@export var attribute_component_name : StringName = "GameplayVitalAttributeComponent"

func _apply(target: Node, _instigator: Node, context: Dictionary) -> void:
	var attr_comp: GameplayAttributeComponent = GameplayAbilitySystem.get_component_by_interface(
		target, attribute_component_name) as GameplayAttributeComponent
	if not is_instance_valid(attr_comp):
		# 如果没有 AttributeComponent，静默失败（不是所有实体都需要属性）
		push_error("GE_AttributeModifier: attr comp is not valid!")
		return

	# 确定 source_id
	var final_source_id: StringName = _resolve_source_id(context)
	var raw_stacks: Variant = context.get("stacks", 1)
	if not (raw_stacks is int or raw_stacks is float):
		push_warning("GE_AttributeModifier: ignored non-numeric stack count")
		return
	var stacks: float = float(raw_stacks)
	if not is_finite(stacks):
		push_warning("GE_AttributeModifier: ignored non-finite stack count")
		return

	# 应用所有修改器
	var batch: Array[GameplayAttributeModifier] = []
	for mod_template: GameplayAttributeModifier in modifiers:
		if not is_instance_valid(mod_template):
			continue
		# 创建修改器的副本（避免修改模板）
		var mod: GameplayAttributeModifier = mod_template.duplicate() as GameplayAttributeModifier
		if not is_instance_valid(mod):
			continue

		# 设置 source_id
		mod.source_id = final_source_id
		mod.value *= stacks
	
		batch.append(mod)
	attr_comp.add_modifiers(batch)

## 移除效果的具体实现
## 注意：Effect 保持无状态特性，通过 context 中的 source_id 来识别要移除的修改器
func _remove(target: Node, instigator: Node, context: Dictionary) -> void:
	_remove_modifiers(target, context)

## 移除修改器的核心逻辑（供 _apply 和 _remove 共用）
func _remove_modifiers(target: Node, context: Dictionary) -> void:
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(target, attribute_component_name)
	if not is_instance_valid(attr_comp):
		# 如果没有 AttributeComponent，静默失败（不是所有实体都需要属性）
		push_error("GE_AttributeModifier: attr comp is not valid!")
		return
		
	# 确定 source_id
	var final_source_id: StringName = _resolve_source_id(context)

	# 批量移除修改器（通过 source_id）
	attr_comp.remove_modifiers_by_source(final_source_id)

func _resolve_source_id(context: Dictionary) -> StringName:
	var context_source: StringName = context.get("source_id", &"")
	if not context_source.is_empty():
		return context_source
	if not source_id.is_empty():
		return StringName("effect." + source_id)
	if context.has(_SUB_EFFECT_SOURCE_KEY):
		return StringName(context[_SUB_EFFECT_SOURCE_KEY])
	return StringName("effect.instance.%d" % get_instance_id())

func _composite_source() -> String:
	if source_id.is_empty():
		return super()
	return "effect.composite.source.%d.%s" % [source_id.length(), source_id]
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
