extends Node
class_name GameplayModifierComponent

## 技能行为修改器组件
## 管理角色身上的所有 GameplayAbilityModifier，并在关键流程点触发钩子
##
## 性能优化：使用索引（Dictionary）避免遍历所有 Modifier

# ========== 数据 ==========
## 所有活跃的修改器
var active_modifiers: Array[GameplayAbilityModifier] = []

## 索引：ability_id -> List[GameplayAbilityModifier]（性能优化）
var _modifiers_by_ability_id: Dictionary[StringName, Array] = {}

## 索引：无过滤条件的通用修改器（影响所有技能）
var _universal_modifiers: Array[GameplayAbilityModifier] = []

# ========== 公共 API ==========

## 添加修改器
## [param] mod: GameplayAbilityModifier 修改器实例
## [param] source: String 来源标识（可选，用于追踪）
func add_modifier(mod: GameplayAbilityModifier, source: String = "") -> void:
	if not is_instance_valid(mod):
		return
	
	if mod in active_modifiers:
		push_warning("GameplayModifierComponent: Modifier already added, skipping.")
		return
	
	# 设置来源
	if not source.is_empty():
		mod.source = source
	
	# 添加到主列表
	active_modifiers.append(mod)
	
	# 更新索引
	_update_index(mod, true)

## 移除修改器
## [param] mod: GameplayAbilityModifier 修改器实例
func remove_modifier(mod: GameplayAbilityModifier) -> void:
	if not is_instance_valid(mod):
		return
	
	if mod not in active_modifiers:
		return
	
	# 从主列表移除
	active_modifiers.erase(mod)
	
	# 更新索引
	_update_index(mod, false)

## 移除所有来自指定来源的修改器
## [param] source: String 来源标识
func remove_modifiers_by_source(source: String) -> void:
	if source.is_empty():
		return
	
	var to_remove: Array[GameplayAbilityModifier] = []
	for mod in active_modifiers:
		if mod.source == source:
			to_remove.append(mod)
	
	for mod in to_remove:
		remove_modifier(mod)

## 清空所有修改器
func clear_all_modifiers() -> void:
	active_modifiers.clear()
	_modifiers_by_ability_id.clear()
	_universal_modifiers.clear()

## 获取所有活跃的修改器
## [return] Array[GameplayAbilityModifier] 修改器数组（只读副本）
func get_all_modifiers() -> Array[GameplayAbilityModifier]:
	return active_modifiers.duplicate()

# ========== 钩子通知（公共 API，由外部系统调用）==========

## 通知：施法前
## [param] ability_comp: GameplayAbilityComponent 技能组件
## [param] ability: GameplayAbility 技能实例
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func notify_before_ability_cast(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	context: Variant
) -> void:
	var ctx = ContextUtils.to_context(context)
	var relevant_modifiers = _get_relevant_modifiers(ability, ability_comp)
	for mod in relevant_modifiers:
		if not is_instance_valid(mod):
			continue
		# Modifier 可能仍使用 Dictionary，转换后传递
		var mod_dict = ctx.to_dict()
		mod.on_before_ability_cast(ability_comp, ability, mod_dict)

## 通知：施法成功后
## [param] ability_comp: GameplayAbilityComponent 技能组件
## [param] ability: GameplayAbility 技能实例
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func notify_after_ability_commit(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	context: Variant
) -> void:
	var ctx = ContextUtils.to_context(context)
	var relevant_modifiers = _get_relevant_modifiers(ability, ability_comp)
	
	# 在循环外创建一次字典，让所有修改器修改同一个字典
	var mod_dict = ctx.to_dict()
	
	for mod in relevant_modifiers:
		if not is_instance_valid(mod):
			continue
		# Modifier 可能仍使用 Dictionary，所有修改器共享同一个字典
		mod.on_after_ability_commit(ability_comp, ability, mod_dict)
	
	# 所有修改器调用完成后，将 Dictionary 的修改同步回 AbilityContext
	_sync_dict_to_context(mod_dict, ctx)

## 通知：技能真正生效前
## [param] ability_comp: GameplayAbilityComponent 技能组件
## [param] ability: GameplayAbility 技能实例
## [param] target: Node 目标
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func notify_before_apply_ability(
	ability_comp: GameplayAbilityComponent,
	ability: GameplayAbility,
	target: Node,
	context: Variant
) -> void:
	var ctx = ContextUtils.to_context(context)
	var relevant_modifiers = _get_relevant_modifiers(ability, ability_comp)
	
	# 在循环外创建一次字典，让所有修改器修改同一个字典
	var mod_dict = ctx.to_dict()
	
	for mod in relevant_modifiers:
		if not is_instance_valid(mod):
			continue
		# Modifier 可能仍使用 Dictionary，所有修改器共享同一个字典
		mod.on_before_apply_ability(ability_comp, ability, target, mod_dict)
	
	# 所有修改器调用完成后，将 Dictionary 的修改同步回 AbilityContext
	_sync_dict_to_context(mod_dict, ctx)

## 通知：效果应用时
## [param] effect: GameplayEffect 效果实例
## [param] target: Node 目标
## [param] instigator: Node 施法者
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func notify_effect_applied(
	effect: GameplayEffect,
	target: Node,
	instigator: Node,
	context: Variant
) -> void:
	var ctx = ContextUtils.to_context(context)
	
	# 在循环外创建一次字典，让所有修改器修改同一个字典
	var mod_dict = ctx.to_dict()
	
	# 效果层暂时遍历所有修改器（因为效果没有 ability_id）
	# 如果未来需要优化，可以给 Effect 也加 ID/Tag 过滤
	for mod in active_modifiers:
		if not is_instance_valid(mod):
			continue
		# Modifier 可能仍使用 Dictionary，所有修改器共享同一个字典
		mod.on_effect_applied(effect, target, instigator, mod_dict)
	
	# 所有修改器调用完成后，将 Dictionary 的修改同步回 AbilityContext
	_sync_dict_to_context(mod_dict, ctx)

# ========== 内部方法 ==========

## 将 Dictionary 的修改同步回 AbilityContext
## 用于在修改器修改 Dictionary 后，将修改同步回 AbilityContext
## [param] mod_dict: Dictionary 修改后的字典
## [param] ctx: AbilityContext 要同步的上下文
func _sync_dict_to_context(mod_dict: Dictionary, ctx: AbilityContext) -> void:
	# 同步关键属性（修改器可能修改的属性）
	if mod_dict.has("extra_projectiles"):
		ctx.extra_projectiles = mod_dict.get("extra_projectiles", 0)
	if mod_dict.has("damage_multiplier_modifier"):
		ctx.damage_multiplier_modifier = mod_dict.get("damage_multiplier_modifier", 1.0)
	if mod_dict.has("cooldown_reduction"):
		ctx.cooldown_reduction = mod_dict.get("cooldown_reduction", 0.0)
	if mod_dict.has("extra_effects"):
		ctx.extra_effects = mod_dict.get("extra_effects", [])
	if mod_dict.has("apply_extra_effects_to_all_targets"):
		ctx.apply_extra_effects_to_all_targets = mod_dict.get("apply_extra_effects_to_all_targets", true)
	# 同步 custom_data（其他自定义数据）
	if mod_dict.has("custom_data") and mod_dict["custom_data"] is Dictionary:
		ctx.custom_data = mod_dict["custom_data"].duplicate()
	else:
		# 将不在基础属性中的键存入 custom_data
		var base_properties = ["instigator", "input_target", "ability", "ability_comp", "ability_id", "ability_level",
			"final_damage", "damage_multiplier_modifier", "extra_effects",
			"apply_extra_effects_to_all_targets", "extra_projectiles", "muzzle_transform",
			"cooldown_reduction", "skip_cooldown", "skip_cost",
			"hit_position", "hit_direction", "projectile", "damage_info",
			"value", "text", "custom_data"]
		for key in mod_dict:
			if key not in base_properties:
				ctx.custom_data[key] = mod_dict[key]

## 获取与指定技能相关的修改器（性能优化：使用索引）
## [param] ability: GameplayAbility 技能实例
## [param] ability_comp: GameplayAbilityComponent 技能组件（用于 Tag 检查）
## [return] Array[GameplayAbilityModifier] 相关修改器列表
func _get_relevant_modifiers(ability: GameplayAbility, ability_comp: GameplayAbilityComponent = null) -> Array[GameplayAbilityModifier]:
	if not is_instance_valid(ability):
		return []
	
	var result: Array[GameplayAbilityModifier] = []
	
	# 1. 添加通用修改器（无过滤条件）
	result.append_array(_universal_modifiers)
	
	# 2. 添加针对此技能的修改器（通过 ID 索引）
	var ability_id = ability.ability_id
	if _modifiers_by_ability_id.has(ability_id):
		result.append_array(_modifiers_by_ability_id[ability_id])
	
	# 3. 过滤：检查每个修改器是否真的影响此技能（处理 Tag 过滤）
	var filtered_result: Array[GameplayAbilityModifier] = []
	for mod in result:
		if mod.affects_ability(ability, ability_comp):
			filtered_result.append(mod)
	
	return filtered_result

## 更新索引（添加或移除时调用）
## [param] mod: GameplayAbilityModifier 修改器
## [param] is_add: bool true=添加，false=移除
func _update_index(mod: GameplayAbilityModifier, is_add: bool) -> void:
	if not is_instance_valid(mod):
		return
	
	# 判断是通用修改器还是特定技能修改器
	var is_universal = mod.affected_ability_ids.is_empty() and mod.affected_ability_tags.is_empty()
	
	if is_universal:
		# 通用修改器
		if is_add:
			if mod not in _universal_modifiers:
				_universal_modifiers.append(mod)
		else:
			_universal_modifiers.erase(mod)
	else:
		# 特定技能修改器：为每个 affected_ability_id 建立索引
		for ability_id in mod.affected_ability_ids:
			if not _modifiers_by_ability_id.has(ability_id):
				_modifiers_by_ability_id[ability_id] = []
			
			var list = _modifiers_by_ability_id[ability_id]
			if is_add:
				if mod not in list:
					list.append(mod)
			else:
				list.erase(mod)
				
				# 如果列表为空，删除索引条目
				if list.is_empty():
					_modifiers_by_ability_id.erase(ability_id)

## 接口方法（用于 GameplayAbilitySystem.get_component_by_interface）
func get_gameplay_modifier_component() -> GameplayModifierComponent:
	return self
