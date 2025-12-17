extends DamageLogicStrategy
class_name SimpleDamageLogic

## 简单伤害计算策略
## 公式：最终伤害 = max(1, 基础伤害)

func calculate(damage_info: DamageInfo, target_attributes: GameplayAttributeComponent) -> float:
	var damage = max(1.0, damage_info.base_damage)
	
	return damage
