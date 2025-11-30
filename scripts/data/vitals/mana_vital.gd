extends VitalBaseResource
class_name ManaVital

## 法力值 Vital
## 处理消耗和恢复

func _init(p_attribute_component: GameplayAttributeComponent, p_max_value_id: StringName = &"max_mana", p_regen_rate_id: StringName = &"mana_regen") -> void:
	super(&"mana", p_attribute_component, p_max_value_id, p_regen_rate_id)

## 尝试消耗法力
## [param] amount: float 要消耗的法力值
## [returns] bool 是否成功消耗
func try_spend_mana(amount: float) -> bool:
	if _current_value >= amount:
		set_current_value(_current_value - amount)
		return true
	else:
		return false # 法力不足
