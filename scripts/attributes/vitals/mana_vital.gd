extends GameplayVital
class_name ManaVital

## Compatibility resource for existing mana assets. New assets can use GameplayVital.

func _init(p_comp: GameplayAttributeComponent = null) -> void:
	# 设置 ManaVital 的默认值（在调用 super 之前设置）
	vital_id = &"mana"
	display_name = "魔法值"
	max_value_attribute = &"max_mana"  # 依赖 "mana" 属性作为上限
	# regen_rate_attribute = &"mana_regen"  # 可选：自动回复
	
## 尝试消耗法力
## [param] amount: float 要消耗的法力值
## [return] bool 是否成功消耗
func try_spend_mana(amount: float) -> bool:
	var component: GameplayVitalAttributeComponent = _owner_comp as GameplayVitalAttributeComponent
	return is_instance_valid(component) and component.try_spend(vital_id, amount)
