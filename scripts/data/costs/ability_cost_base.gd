@abstract
extends Resource
class_name AbilityCostBase

## 技能消耗器/限制器基类（抽象类）
## 用于定义技能施放时的资源消耗或限制条件
## 支持多种消耗类型：魔法值、怒气、能量、生命值等
## 也支持限制条件：如"生命值低于50%时无法使用"

## 检查是否可以支付消耗（不实际消耗）
## [param] ability_comp: GameplayAbilityComponent 能力组件
## [param] instigator: Node 施法者
## [return] bool 是否可以支付
func can_pay(ability_comp: Node, instigator: Node) -> bool:
	return _can_pay(ability_comp, instigator)

## 尝试支付消耗（实际消耗资源）
## [param] ability_comp: GameplayAbilityComponent 能力组件
## [param] instigator: Node 施法者
## [return] bool 是否成功支付
func try_pay(ability_comp: Node, instigator: Node) -> bool:
	if not _can_pay(ability_comp, instigator):
		return false
	return _try_pay(ability_comp, instigator)

## 获取消耗描述（用于UI显示）
## [return] String 消耗描述文本
func get_cost_description() -> String:
	return _get_cost_description()

## [子类重写] 检查是否可以支付消耗
## [param] ability_comp: GameplayAbilityComponent 能力组件
## [param] instigator: Node 施法者
## [return] bool 是否可以支付
@abstract func _can_pay(ability_comp: Node, instigator: Node) -> bool

## [子类重写] 尝试支付消耗
## [param] ability_comp: GameplayAbilityComponent 能力组件
## [param] instigator: Node 施法者
## [return] bool 是否成功支付
@abstract func _try_pay(ability_comp: Node, instigator: Node) -> bool

## [子类重写] 获取消耗描述
## [return] String 消耗描述文本
func _get_cost_description() -> String:
	return "消耗: 未知"
