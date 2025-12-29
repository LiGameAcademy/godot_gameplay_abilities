extends GameplayEffect
class_name GE_AbilityModifier

## 技能行为修改器效果
## 在目标上应用技能行为修改器
## 支持通过 source_id 批量移除

@export var modifiers: Array[GameplayAbilityModifier] = []
## 来源ID（用于批量移除）
## 如果不设置，会从 context 中读取 source_id
## 如果 context 中也没有，则使用 "effect." + 效果资源路径
@export var source_id: String = ""

func _apply(target: Node, instigator: Node, context: AbilityContext) -> void:
	var modifier_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayModifierComponent")
	if not modifier_comp:
		# 如果没有 ModifierComponent，静默失败（不是所有实体都需要修改器）
		return
	
	# 确定 source_id
	var final_source_id = source_id
	if final_source_id.is_empty():
		if context.custom_data.has("source_id") and context.custom_data["source_id"] is String:
			final_source_id = context.custom_data["source_id"]
		else:
			# 使用效果资源路径作为默认 source_id
			final_source_id = "effect." + str(get_path())
	
	# 应用所有修改器
	for mod in modifiers:
		if is_instance_valid(mod):
			modifier_comp.add_modifier(mod, final_source_id)

## 移除效果的具体实现
## 注意：Effect 保持无状态特性，通过 context 中的 source_id 来识别要移除的修改器
func _remove(target: Node, instigator: Node, context: AbilityContext) -> void:
	_remove_modifiers(target, context)

## 移除修改器的核心逻辑（供 _apply 和 _remove 共用）
func _remove_modifiers(target: Node, context: AbilityContext) -> void:
	var modifier_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayModifierComponent")
	if not modifier_comp:
		# 如果没有 ModifierComponent，静默失败
		return
	
	# 确定 source_id
	var final_source_id = source_id
	if final_source_id.is_empty():
		if context.custom_data.has("source_id"):
			var ctx_source_id = context.custom_data["source_id"]
			if ctx_source_id is String:
				final_source_id = ctx_source_id
			elif ctx_source_id is StringName:
				final_source_id = str(ctx_source_id)
		else:
			push_warning("GE_RemoveAbilityModifier: source_id is empty and not found in context")
			return
	
	# 批量移除修改器
	modifier_comp.remove_modifiers_by_source(final_source_id)

func _get_description() -> String:
	var desc = "Apply ability modifiers: "
	for mod in modifiers:
		if is_instance_valid(mod):
			desc += "%s " % mod.get_script().get_path()
	return desc

