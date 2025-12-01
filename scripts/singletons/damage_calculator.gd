extends Node

## 伤害计算中心（单例）

var _strategy: DamageLogicStrategy = SimpleDamageLogic.new()

# 允许业务层在游戏启动时注入自定义策略
func set_strategy(strategy: DamageLogicStrategy) -> void:
	_strategy = strategy

## 计算最终伤害
## [param] damage_info: DamageInfo 伤害信息
## [param] target: Variant 目标（HealthComponent 或 HealthVital，采用鸭子类型）
## [returns] float 最终伤害值
func calculate_final_damage(damage_info: DamageInfo, target_comp: GameplayAttributeComponent) -> float:
	if not is_instance_valid(_strategy):
		return 0.0
	var final_damage = _strategy.calculate(damage_info, target_comp)
	return max(0.0, final_damage)
