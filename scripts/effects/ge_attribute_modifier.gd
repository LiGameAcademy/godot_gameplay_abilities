extends GameplayEffect
class_name GE_AttributeModifier

## 属性修改器效果
## 在目标上应用属性修改器
## 支持通过 source_id 批量移除

@export var modifiers: Array[GameplayAttributeModifier] = []
## 来源ID（用于批量移除）
## 如果不设置，会从 context 中读取 source_id
## 如果 context 中也没有，则使用 "effect." + 效果资源路径
@export var source_id: StringName = &""

func _apply(target: Node, instigator: Node, context: AbilityContext) -> void:
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayAttributeComponent")
	if not attr_comp:
		# 如果没有 AttributeComponent，静默失败（不是所有实体都需要属性）
		return
	
	# 确定 source_id
	var final_source_id = source_id
	if final_source_id.is_empty():
		if context.custom_data.has("source_id") and context.custom_data["source_id"] is StringName:
			final_source_id = context.custom_data["source_id"]
		else:
			# 使用效果资源路径作为默认 source_id
			final_source_id = "effect." + str(get_path())
	
	# 应用所有修改器
	for mod_template in modifiers:
		if not is_instance_valid(mod_template):
			continue
		
		# 创建修改器的副本（避免修改模板）
		var mod = mod_template.duplicate() as GameplayAttributeModifier
		if not is_instance_valid(mod):
			continue
		
		# 设置 source_id（如果模板中没有设置）
		if mod.source_id.is_empty():
			mod.source_id = final_source_id
		
		# 如果 context 中有 stacks 信息，可以用于层数计算
		if context.custom_data.has("stacks") and context.custom_data["stacks"] is int:
			var stacks: int = context.custom_data["stacks"]
			# 如果配置了 value_per_stack，可以根据层数调整值
			# 注意：这里假设在状态数据中配置了 base_value 和 value_per_stack
			# 如果需要在效果中配置，可以添加相应的导出变量
			pass
		
		# 应用修改器
		attr_comp.add_modifier(mod)

## 移除效果的具体实现
## 注意：Effect 保持无状态特性，通过 context 中的 source_id 来识别要移除的修改器
func _remove(target: Node, instigator: Node, context: AbilityContext) -> void:
	_remove_modifiers(target, context)

## 移除修改器的核心逻辑（供 _apply 和 _remove 共用）
func _remove_modifiers(target: Node, context: AbilityContext) -> void:
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayAttributeComponent")
	if not attr_comp:
		# 如果没有 AttributeComponent，静默失败
		return
	
	# 确定 source_id
	var final_source_id = source_id
	if final_source_id.is_empty():
		if context.custom_data.has("source_id"):
			var ctx_source_id = context.custom_data["source_id"]
			if ctx_source_id is StringName:
				final_source_id = ctx_source_id
			elif ctx_source_id is String:
				final_source_id = StringName(ctx_source_id)
		else:
			push_warning("GE_RemoveAttributeModifier: source_id is empty and not found in context")
			return
	
	# 批量移除修改器
	attr_comp.remove_modifiers_by_source(final_source_id)

func _get_description() -> String:
	var desc = "Apply attribute modifiers: "
	for mod in modifiers:
		if is_instance_valid(mod):
			desc += "%s %s " % [mod.attribute_id, mod.value]
	return desc

