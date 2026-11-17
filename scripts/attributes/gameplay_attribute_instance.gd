extends RefCounted
class_name GameplayAttributeInstance

## 属性运行时实例
## 核心职责：维护 BaseValue，管理 Modifiers，计算 FinalValue

const ModifierType = GameplayAttributeModifier.ModifierType

var attribute_def: GameplayAttribute  					## 属性定义（资源）
var base_value: float = 0.0 : set = _set_base_value		## 基础值
## Each registration keeps its own configuration, keyed by the caller's resource.
var _modifiers: Dictionary[GameplayAttributeModifier, GameplayAttributeModifier] = {}
var _cached_final_value: float = 0.0
var _dirty: bool = true

signal value_changed(old_val: float, new_value: float)	## 当最终值实际改变时发出

func _init(attr_res: GameplayAttribute = null, init_val: float = 0.0) -> void:
	attribute_def = attr_res
	base_value = init_val
	if _dirty and is_instance_valid(attribute_def):
		_recalculate_value()

## Returns the final value after modifiers and bounds.
## [return] float 最终值
func get_value() -> float:
	if _dirty:
		_recalculate_value()
	return _cached_final_value

## Registers a snapshot. Remove and re-add to apply changes to the source resource.
func add_modifier(mod: GameplayAttributeModifier) -> void:
	if not is_instance_valid(mod) or _modifiers.has(mod):
		return
	if not is_finite(mod.value):
		push_warning("GameplayAttributeInstance: ignored non-finite modifier")
		return
	_modifiers[mod] = GameplayAttributeModifier.new(mod.attribute_id, mod.value, mod.modifier_type, mod.source_id)
	_on_data_changed()

## Removes the original registration even if its resource was edited later.
func remove_modifier(mod: GameplayAttributeModifier) -> void:
	if _modifiers.erase(mod):
		_on_data_changed()

## Removes all registrations from the source captured when they were added.
func remove_modifiers_by_source(source_id: StringName) -> void:
	if source_id.is_empty():
		return
	var removed: bool = false
	for mod: GameplayAttributeModifier in _modifiers.keys():
		if _modifiers[mod].source_id == source_id:
			_modifiers.erase(mod)
			removed = true
	if removed:
		_on_data_changed()

func _recalculate_value() -> void:
	var sum_add: float = 0.0
	var sum_multiplier: float = 0.0
	var first_override: GameplayAttributeModifier = null
	var override_count: int = 0
	for mod: GameplayAttributeModifier in _modifiers.values():
		match mod.modifier_type:
			ModifierType.ADD:
				sum_add += mod.value
			ModifierType.MULTIPLY:
				sum_multiplier += mod.value
			ModifierType.OVERRIDE:
				if first_override == null:
					first_override = mod
				override_count += 1
	if override_count > 1:
		push_warning("GameplayAttributeInstance: multiple overrides, using the first registration")

	var final: float = (base_value + sum_add) * (1.0 + sum_multiplier)
	if first_override != null:
		final = first_override.value
	if is_instance_valid(attribute_def):
		var minimum: float = attribute_def.min_value
		var maximum: float = attribute_def.max_value
		if minimum <= maximum and minimum < INF and maximum > -INF:
			final = clampf(final, minimum, maximum)
		else:
			push_warning("GameplayAttributeInstance: ignored invalid attribute bounds")
	else:
		push_warning("AttributeInstance: attribute def is not valid!")
	if is_finite(final):
		_cached_final_value = final
	else:
		push_warning("GameplayAttributeInstance: kept the previous value after non-finite calculation")
	_dirty = false

## 设置基础值（会触发重新计算）
func _set_base_value(val: float) -> void:
	if not is_finite(val):
		push_warning("GameplayAttributeInstance: ignored non-finite base value")
		return
	if base_value == val:
		return
	
	base_value =val
	_on_data_changed()

## 内部通知：数据变化时触发重新计算
func _on_data_changed() -> void:
	var old_val: float = _cached_final_value
	_dirty = true
	var new_val: float = get_value()
	# Tiny effective changes can be amplified by dependencies; never discard them.
	if old_val != new_val:
		value_changed.emit(old_val, new_val)
