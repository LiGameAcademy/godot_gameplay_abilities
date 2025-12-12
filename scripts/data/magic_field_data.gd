extends Resource
class_name MagicFieldData

## 魔法场数据资源
## 用于配置魔法场的所有参数，在 Ability 中配置，传递给 MagicFieldBase
##
## 设计目的：
## - 解耦配置和运行时逻辑
## - 让魔法场数据可复用（多个技能可以共享同一个 MagicFieldData）
## - 符合 Godot 的资源系统设计

## 周期性效果的目标选择模式
enum TargetSelectionMode {
	RANDOM,    ## 随机选择
	NEAREST,   ## 最近的优先
	ALL        ## 所有目标
}

@export_group("Lifetime")
## 持续时间（秒，-1 为永久）
@export var duration: float = 5.0

@export_group("Trigger Mode")
## 周期性触发间隔（秒）
## - 如果 > 0：魔法场会周期性触发，每次触发时对范围内的所有目标应用 payload_statuses
##   单位进入/退出范围时，不立即应用/移除状态，只维护目标列表
## - 如果 <= 0：单位进入范围时立即应用 payload_statuses，退出时移除
##   不进行周期性触发
@export var periodic_trigger_interval: float = 0.0

@export_group("Periodic Effect")
## 周期性效果的目标选择模式（仅在 periodic_trigger_interval > 0 时有效）
## 当魔法场周期性触发时，会根据此模式选择目标并应用 payload_statuses
@export var periodic_target_selection_mode: TargetSelectionMode = TargetSelectionMode.ALL
## 周期性效果的目标数量（-1 为全部，仅在 RANDOM 和 NEAREST 模式下有效）
@export var periodic_target_count: int = -1

@export_group("Scene")
## 魔法场场景（必须继承自 MagicFieldBase）
## 场景是魔法场的核心定义，包含 Area3D 和视觉效果
@export var magic_field_scene: PackedScene = null
## 携带的状态列表（弹头）
## 当目标进入区域或周期性触发时，会将此列表中的状态应用给目标
@export var payload_statuses: Array[GameplayStatusData] = []

## 应用数据到魔法场实例
## [param] magic_field: MagicFieldBase 魔法场实例
func apply_to_magic_field(magic_field: MagicFieldBase) -> void:
	if not is_instance_valid(magic_field):
		push_error("MagicFieldData: Cannot apply to invalid magic field")
		return
	
	# 应用生命周期配置
	magic_field.duration = duration
	
	# 应用触发模式配置
	magic_field.periodic_trigger_interval = periodic_trigger_interval
	
	# 应用周期性效果配置
	magic_field.periodic_target_selection_mode = periodic_target_selection_mode
	magic_field.periodic_target_count = periodic_target_count

	# 应用弹头配置
	magic_field.payload_statuses = payload_statuses