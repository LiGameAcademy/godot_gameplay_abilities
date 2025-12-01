extends DamageLogicStrategy
class_name SimpleDamageLogic

@export var defense_attribute: StringName = &"defense"

func calculate(damage_info: DamageInfo, target_attributes: GameplayAttributeComponent) -> float:
    # 1. 简单的减法公式
    var defense = target_attributes.get_value(defense_attribute)
    var damage = max(1.0, damage_info.base_damage - defense)
    
    return damage