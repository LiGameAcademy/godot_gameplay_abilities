extends RefCounted
class_name GameplayAttributeInstance

## 属性运行时实例
## 核心职责：维护 BaseValue，管理 Modifiers，计算 FinalValue

const ModifierType = GameplayAttributeModifier.ModifierType

# --- 数据 ---
var attribute_def: GameplayAttribute
var base_value: float = 0.0 : set = _set_base_value
var _modifiers: Array[GameplayAttributeModifier] = []

# --- 等级成长支持 ---
## 可扩展数值（如果设置，会基于等级计算 base_value）
var scalable_value: ScalableValue = null
## 当前等级（用于计算 scalable_value）
var current_level: int = 1 : set = _set_current_level

# --- 缓存与脏标记 (性能优化) ---
var _dirty: bool = true
var _cached_final_value: float = 0.0

# --- 信号 ---
# 仅在最终值实际改变时发出
signal value_changed(old_val: float, new_val: float)

func _init(definition: GameplayAttribute, initial_value: float, p_scalable_value: ScalableValue = null) -> void:
	attribute_def = definition
	scalable_value = p_scalable_value
	
	# 如果设置了 scalable_value，使用它计算初始值
	if is_instance_valid(scalable_value):
		base_value = scalable_value.get_value_at_level(current_level)
	else:
		base_value = initial_value

func get_value() -> float:
	if _dirty:
		_recalculate_value()
	return _cached_final_value

## 设置可扩展数值（会重新计算 base_value）
func set_scalable_value(value: ScalableValue) -> void:
	scalable_value = value
	if is_instance_valid(scalable_value):
		base_value = scalable_value.get_value_at_level(current_level)
		_on_data_changed()

# --- 修改器管理 ---
func add_modifier(mod: GameplayAttributeModifier) -> void:
	_modifiers.append(mod)
	_on_data_changed()

func remove_modifier(mod: GameplayAttributeModifier) -> void:
	_modifiers.erase(mod)
	_on_data_changed()

# --- Setter ---
func _set_base_value(val: float) -> void:
	if base_value == val: return
	base_value = val
	_on_data_changed()

## 设置等级（会重新计算 base_value）
func _set_current_level(level: int) -> void:
	if current_level == level: return
	current_level = max(1, level)  # 等级至少为 1
	
	# 如果设置了 scalable_value，重新计算 base_value
	if is_instance_valid(scalable_value):
		var old_base = base_value
		base_value = scalable_value.get_value_at_level(current_level)
		# 如果 base_value 变化，触发重新计算
		if not is_equal_approx(old_base, base_value):
			_on_data_changed()
	else:
		# 没有 scalable_value，只更新等级标记
		_on_data_changed()

# --- 核心计算逻辑 (Lazy Evaluation) ---
func _recalculate_value() -> void:
	var final = base_value
	
	# 1. 预计算：先归类，避免多次遍历 (如果 Modifier 很多，这里可以进一步优化)
	var sum_add = 0.0
	var product_mult = 0.0
	var has_override = false
	var override_val = 0.0
	
	for mod in _modifiers:
		match mod.type:
			ModifierType.OVERRIDE:
				has_override = true
				override_val = mod.value
				break # 覆盖优先级最高，直接停止计算（或者根据需求决定优先级）
			ModifierType.ADD:
				sum_add += mod.value
			ModifierType.MULTIPLY:
				product_mult += mod.value # 注意：通常配置 0.5 代表 +50%
				# 如果你的配置是 1.5 代表 x1.5，则这里应该是 product_mult *= mod.value
				# 建议使用：Base * (1 + Sum(Mult_Mods)) 的累加乘逻辑，防止指数爆炸
				# 或者：Base * Product(Mult_Mods) 的连乘逻辑
				# 这里采用 RPG 常用的累加乘：Base * (1 + 0.1 + 0.2)
	
	if has_override:
		final = override_val
	else:
		# 标准公式：(基础值 + 加法修正) * (1 + 乘法修正总和)
		# 假设 Modifier 的 Multiply 填 0.1 代表增加 10%
		final = (base_value + sum_add) * (1.0 + product_mult)
		
		# 另一种常见公式（连乘）：(Base + Add) * Mult1 * Mult2
		# final = (base_value + sum_add) * product_mult
	
	# 限制范围
	if attribute_def:
		final = clampf(final, attribute_def.min_value, attribute_def.max_value)
	
	_cached_final_value = final
	_dirty = false

# --- 内部通知 ---
func _on_data_changed() -> void:
	var old_val = _cached_final_value
	_dirty = true # 标记为脏，下次获取时重算
	var new_val = get_value() # 立即重算以触发信号（也可以选择延迟触发）
	
	if not is_equal_approx(old_val, new_val):
		value_changed.emit(old_val, new_val)
