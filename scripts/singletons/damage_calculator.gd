extends Node

## 伤害计算中心（单例）
## 使用策略模式，支持自定义伤害公式

var _strategy: DamageLogicStrategy = SimpleDamageLogic.new()

## 设置伤害计算策略
## [param] strategy: DamageLogicStrategy 自定义策略
func set_strategy(strategy: DamageLogicStrategy) -> void:
	_strategy = strategy

## 计算最终伤害
## [param] damage_info: DamageInfo 伤害信息
## [param] target_comp: GameplayAttributeComponent 目标的属性组件
## [return] float 最终伤害值
func calculate_final_damage(damage_info: DamageInfo, target_comp: GameplayAttributeComponent) -> float:
	if not is_instance_valid(_strategy): return 0.0
	
	var final_damage = _strategy.calculate(damage_info, target_comp)
	return max(0.0, final_damage)
