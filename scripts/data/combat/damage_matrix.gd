extends Resource
class_name DamageMatrix

## 伤害矩阵
## 定义不同攻击类型对不同护甲类型的伤害倍率

# 字典的结构: { AttackType: { ArmorType: float } }
@export var _matrix: Dictionary[StringName, Dictionary] = {}

## 获取伤害倍率
func get_damage_multiplier(attack_type: StringName, armor_type: StringName) -> float:
	if not _matrix.has(attack_type):
		push_error("Damage matrix: Attack type not found %s %s" % [attack_type, armor_type])
		return 1.0
	var attack_entry : Dictionary = _matrix.get(attack_type, {})
	if not attack_entry.has(armor_type):
		print("Damage matrix: Armor type not found: %s %s" % [attack_type, armor_type])
		return 1.0
	return attack_entry.get(armor_type, 1.0)

