extends Node

## 伤害计算中心（单例）
## 负责计算最终伤害值，包括类型克制和护甲减免

const ARMOR_FACTOR = 0.06

var _damage_matrix : DamageMatrix = null

## 设置伤害矩阵
func set_damage_matrix(p_damage_matrix: DamageMatrix) -> void:
	_damage_matrix = p_damage_matrix

## 计算最终伤害
## [param] damage_info: DamageInfo 伤害信息
## [param] target: Variant 目标（HealthComponent 或 HealthVital，采用鸭子类型）
## [returns] float 最终伤害值
func calculate_final_damage(damage_info: DamageInfo, target: HealthVital) -> float:
	var base_damage = damage_info.base_damage

	# 1. 计算类型克制
	var attack_type_id = damage_info.attack_type.get_id() if damage_info.attack_type else &""
	
	# 使用鸭子类型获取护甲类型
	var armor_type = null
	if "armor_type" in target:
		armor_type = target.armor_type
	var armor_type_id = armor_type.get_id() if armor_type else &""

	var matrix_factor = _get_damage_multiplier(attack_type_id, armor_type_id)
	var damage_after_matrix = base_damage * matrix_factor

	# 2. 计算护甲减免
	# 使用鸭子类型获取护甲值
	var armor_value: float = 0.0
	if "armor_value" in target:
		armor_value = target.armor_value
	
	var reduction_factor := _get_armor_reduction_factor(armor_value)
	var final_damage : float = damage_after_matrix * (1 - reduction_factor)
	
	return max(0.0, final_damage)

func _get_damage_multiplier(attack_type_id: StringName, armor_type_id: StringName) -> float:
	if not is_instance_valid(_damage_matrix):
		push_error("DamageCalculator: damage matrix is not set")
		return 1.0
	# 从资源中查找倍率
	var multiplier : float = _damage_matrix.get_damage_multiplier(attack_type_id, armor_type_id)
	return multiplier

## 护甲减伤公式 (以WC3的为例)
## (护甲 * 0.05) / (1 + 护甲 * 0.05)
func _get_armor_reduction_factor(armor_value: float) -> float:
	if armor_value >= 0:
		return (armor_value * 0.05) / (1.0 + armor_value * 0.05)
	else:
		# 负甲增加伤害
		return 1.0 - pow(0.95, -armor_value)
