@abstract
extends Resource
class_name DamageLogicStrategy

## 伤害计算策略基类
## 业务层继承此类并重写 calculate 方法来自定义伤害公式

## 核心计算接口
## [param] damage_info: DamageInfo 伤害信息（包含基础伤害、攻击者等）
## [param] target: Node 防御者节点
## [param] instigator: Node 攻击者节点
## [param] context: Dictionary 上下文信息（包含属性组件、伤害倍率等）
## [return] float 最终伤害值
@abstract func calculate(damage_info: DamageInfo, target: Node, instigator: Node, context: Dictionary) -> float
