extends Resource
class_name ScalableValue

## 可扩展数值（随等级成长）
## 使用 Curve 定义数值随等级的变化曲线
## 如果未设置 curve，则使用固定值（向后兼容）

@export_group("Fixed Value (Backward Compatible)")
## 固定值（如果未设置 curve，使用此值）
@export var fixed_value: float = 0.0

@export_group("Level Scaling")
## 是否启用等级成长
@export var use_level_scaling: bool = false
## 成长曲线（X 轴 = 等级，Y 轴 = 数值）
## 例如：等级 1 = 10，等级 10 = 50，等级 20 = 100
@export var growth_curve: Curve = null
## 基础等级（曲线采样时的起始等级偏移）
## 例如：base_level = 1，则等级 1 对应曲线的 X=0
@export var base_level: int = 1

## 获取指定等级下的数值
## [param] level: int 当前等级
## [return] float 计算后的数值
func get_value_at_level(level: int) -> float:
	if not use_level_scaling or not is_instance_valid(growth_curve):
		return fixed_value
	
	# 计算曲线采样点（相对于 base_level）
	var curve_x = float(level - base_level)
	# 确保 X 值在曲线范围内
	curve_x = maxf(0.0, curve_x)
	
	# 从曲线采样
	var value = growth_curve.sample(curve_x)
	return value

## 获取基础值（等级 1 时的值）
## [return] float 基础值
func get_base_value() -> float:
	return get_value_at_level(1)

## 获取最大等级时的值（用于预览）
## [param] max_level: int 最大等级
## [return] float 最大等级时的值
func get_max_value(max_level: int = 100) -> float:
	return get_value_at_level(max_level)

