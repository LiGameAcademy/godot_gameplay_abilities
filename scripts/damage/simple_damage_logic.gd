extends DamageLogicStrategy
class_name SimpleDamageLogic

## 简单伤害计算策略
## 公式：最终伤害 = max(1, 基础伤害 * 伤害倍率)

func calculate(damage_info: DamageInfo, target: Node, instigator: Node, context: Dictionary) -> float:
	# 获取伤害倍率（从 context 或默认值）
	var damage_multiplier = context.get("damage_multiplier", 1.0)
	var damage_multiplier_modifier = context.get("damage_multiplier_modifier", 1.0)
	var total_multiplier = damage_multiplier * damage_multiplier_modifier
	
	# 计算最终伤害
	var damage = max(1.0, damage_info.base_damage * total_multiplier)
	
	return damage
