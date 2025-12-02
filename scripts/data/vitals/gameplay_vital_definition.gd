extends Resource
class_name GameplayVitalDefinition

## Vital 定义资源
## 仅用于配置数据模板，不存储运行时状态

@export_group("Identity")
@export var vital_id: StringName = &"health"
@export var display_name: String = "Health"

@export_group("Attribute Dependencies")
## 决定最大值的属性 ID (如 max_health)
@export var max_value_attribute: StringName = &"health"
## 决定恢复速度的属性 ID (如 health_regen)，留空则不自动恢复
@export var regen_rate_attribute: StringName = &""
