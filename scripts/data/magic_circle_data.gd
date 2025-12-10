extends Resource
class_name MagicCircleData

## 魔法阵数据资源
## 用于配置魔法阵的所有参数，在 MagicCircleAbility 中配置，传递给 MagicCircleBase
##
## 设计目的：
## - 解耦配置和运行时逻辑
## - 让魔法阵数据可复用（多个技能可以共享同一个 MagicCircleData）
## - 符合 Godot 的资源系统设计

@export_group("Magic Circle Settings")
## 魔法阵场景（必须继承自 MagicCircleBase）
@export var magic_circle_scene: PackedScene = null
## 魔法阵类型
@export var circle_type: MagicCircleBase.MagicCircleType = MagicCircleBase.MagicCircleType.INSTANT

@export_group("Periodic Settings")
## 周期时间（秒，仅周期性魔法阵使用）
@export var period: float = 1.0
## 持续时间（秒，仅周期性魔法阵使用，-1 为永久）
@export var duration: float = 5.0

@export_group("Targeting & Effects")
## 目标筛选策略（可选，如果未设置则使用 Ability 的 targeting_strategy）
@export var targeting_strategy: TargetingStrategy = null
## 效果列表（可选，如果未设置则使用 Ability 的 target_effects）
@export var effects: Array[GameplayEffect] = []

## 应用数据到魔法阵实例
## [param] magic_circle: MagicCircleBase 魔法阵实例
func apply_to_magic_circle(magic_circle: MagicCircleBase) -> void:
	if not is_instance_valid(magic_circle):
		push_error("MagicCircleData: Cannot apply to invalid magic circle")
		return
	
	# 应用魔法阵配置
	magic_circle.circle_type = circle_type
	magic_circle.period = period
	magic_circle.duration = duration
	
	# 应用目标筛选策略（如果配置了）
	if is_instance_valid(targeting_strategy):
		magic_circle.targeting_strategy = targeting_strategy.duplicate(true)
	
	# 应用效果列表（如果配置了）
	if not effects.is_empty():
		magic_circle.effects_to_apply = effects.duplicate(true)

