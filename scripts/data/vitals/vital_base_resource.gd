extends Resource
class_name VitalBaseResource

## Vital 基类
## 表示一个资源实例（如生命值、法力值等）
## 维护当前值状态和处理当前值与最大值的关系

## Vital ID（用于标识）
@export var vital_id: StringName
## 属性ID配置
@export var max_value_id: StringName = &""         ## 属性ID: 最大值
@export var regen_rate_id: StringName = &""       ## 属性ID: 恢复速率

## 属性组件引用
var attribute_component: GameplayAttributeComponent

## 当前值（运行时状态）
var _current_value: float = 0.0

## 最大值（从属性组件获取）
var max_value: float:
	get:
		if not is_instance_valid(attribute_component):
			return 1.0
		return attribute_component.get_value(max_value_id)
	set(value):
		if is_instance_valid(attribute_component):
			attribute_component.set_value(max_value_id, value)

## 恢复速率（从属性组件获取）
var regen_rate: float:
	get:
		if not is_instance_valid(attribute_component):
			return 0.0
		if not attribute_component.has_attribute(regen_rate_id):
			return 0.0
		return attribute_component.get_value(regen_rate_id)
	set(value):
		if not is_instance_valid(attribute_component):
			return
		if not attribute_component.has_attribute(regen_rate_id):
			push_error("Vital: Attribute %s not found!" % regen_rate_id)
			return
		attribute_component.set_value(regen_rate_id, value)

signal value_changed(new_value: float, max_value: float) ## 值变化信号
signal max_value_changed(new_max_value: float) ## 最大值变化信号
signal regen_rate_changed(new_regen_rate: float) ## 恢复速率变化信号

func _init(p_vital_id: StringName, p_attribute_component: GameplayAttributeComponent, p_max_value_id: StringName, p_regen_rate_id: StringName = &"") -> void:
	vital_id = p_vital_id
	attribute_component = p_attribute_component
	max_value_id = p_max_value_id
	regen_rate_id = p_regen_rate_id
	
	# 初始化当前值为最大值
	_current_value = max_value
	
	# 监听属性变化
	if is_instance_valid(attribute_component):
		if not attribute_component.attribute_value_changed.is_connected(_on_attribute_value_changed):
			attribute_component.attribute_value_changed.connect(_on_attribute_value_changed)

## 处理自动恢复（由 VitalComponent 调用）
func process_regen(delta: float) -> void:
	if regen_rate == 0.0:
		return
	set_current_value(_current_value + regen_rate * delta)

## 设置当前值
func set_current_value(value: float) -> void:
	_current_value = clampf(value, 0.0, max_value)
	value_changed.emit(_current_value, max_value)

## 获取当前值
func get_current_value() -> float:
	return _current_value

## 获取最大值
func get_max_value() -> float:
	return max_value

## 获取恢复速率
func get_regen_rate() -> float:
	return regen_rate

## 获取比例 (0.0 - 1.0)
func get_ratio() -> float:
	if max_value == 0:
		return 0.0
	return clampf(_current_value / max_value, 0.0, 1.0)

## 属性值变化回调
func _on_attribute_value_changed(attribute_id: StringName, value: float) -> void:
	match attribute_id:
		max_value_id:
			# 最大值变化，需要调整当前值
			if _current_value > value:
				# 当前值超过新的最大值，限制为最大值
				set_current_value(value)
			max_value_changed.emit(value)
		regen_rate_id:
			regen_rate_changed.emit(value)
