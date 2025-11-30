extends Resource
class_name DamageInfo

## 伤害信息数据包
## 包含伤害的所有相关信息

## 伤害来源
var instigator: Node = null                      ## 伤害的最终源头
var source_component: Node = null                ## 伤害的直接来源组件（采用鸭子类型，不依赖具体类型）

## 伤害属性
var base_damage: float = 0.0                    ## 基础伤害值（未计算减免前）
var attack_type: AttackType = null               ## 攻击类型
var is_crit: bool = false                        ## 是否暴击

func _init(p_instigator: Node = null, p_source_component: Node = null, p_base_damage: float = 0.0, p_attack_type: AttackType = null, p_is_crit: bool = false) -> void:
	instigator = p_instigator
	source_component = p_source_component
	base_damage = p_base_damage
	attack_type = p_attack_type
	is_crit = p_is_crit

