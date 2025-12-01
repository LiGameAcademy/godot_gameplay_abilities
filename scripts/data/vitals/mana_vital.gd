extends GameplayVital
class_name ManaVital

## 法力值 Vital
## 处理消耗和恢复

## 尝试消耗法力
## [param] amount: float 要消耗的法力值
## [returns] bool 是否成功消耗
func try_spend_mana(amount: float) -> bool:
	var vital_id = definition.vital_id
	if not _owner_comp.has_sufficient_vital(vital_id, amount):
		return false
	_owner_comp.modify_vital(vital_id, -amount)
	return true
