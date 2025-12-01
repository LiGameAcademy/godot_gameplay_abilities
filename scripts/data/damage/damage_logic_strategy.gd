@abstract
extends Resource
class_name DamageLogicStrategy

## 伤害计算策略基类
## 业务层继承此类并重写 calculate 方法来自定义伤害公式

## 核心计算接口
## [param] damage_info: 包含基础伤害、攻击者、攻击类型等
## [param] target_attributes: 防御者的属性组件（用于获取护甲、魔抗等）
## [param] target_tags: 防御者的标签（用于判断易伤、无敌等）
## [return] 最终伤害值
@abstract func calculate(damage_info: DamageInfo, target_attributes: GameplayAttributeComponent) -> float