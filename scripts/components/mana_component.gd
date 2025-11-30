extends VitalComponent
class_name ManaComponent

## 法力值组件
## 管理实体的法力值，处理消耗和恢复

func _ready() -> void:
	super._ready()

## 【公共API】尝试消耗法力
## [param] amount: float 要消耗的法力值
## [returns] bool 是否成功消耗
func try_spend_mana(amount: float) -> bool:
	if _current_value >= amount:
		_current_value -= amount
		value_changed.emit(_current_value, _max_value)
		return true
	else:
		return false # 法力不足

