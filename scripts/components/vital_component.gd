extends Node
class_name VitalComponent

## 资源组件基类（采用鸭子类型设计，不继承基类）
## 管理一个由 AttributeComponent 驱动的"资源" (如HP, MP)
## 子类：HealthComponent、ManaComponent

@export var _attribute_comp: AttributeComponent

@export_group("Attribute IDs")
@export var max_value_id: StringName = &""         ## 属性ID: 最大值
@export var regen_rate_id: StringName = &""         ## 属性ID: 恢复速率

var _current_value: float = 0.0    ## 当前值
var _max_value: float = 1.0:        ## 最大值
	get:
		if not is_instance_valid(_attribute_comp):
			return 1.0
		return _attribute_comp.get_value(max_value_id)
	set(value):
		if is_instance_valid(_attribute_comp):
			_attribute_comp.set_value(max_value_id, value)
var _regen_rate: float = 0.0:      ## 恢复速率
	get:
		if not is_instance_valid(_attribute_comp):
			return 0.0
		if not _attribute_comp.has_attribute(regen_rate_id):
			return 0.0
		return _attribute_comp.get_value(regen_rate_id)
	set(value):
		if not is_instance_valid(_attribute_comp):
			return
		if not _attribute_comp.has_attribute(regen_rate_id):
			push_error("VitalComponent: Attribute %s not found!" % regen_rate_id)
			return
		_attribute_comp.set_value(regen_rate_id, value)

signal value_changed(new_value: float, max_value: float) ## 值变化信号
signal max_value_changed(new_max_value: float) ## 最大值变化信号
signal regen_rate_changed(new_regen_rate: float) ## 恢复速率变化信号

func _ready() -> void:
	if not is_instance_valid(_attribute_comp):
		push_error("%s: AttributeComponent is not set!" % self.name)
		return
	_current_value = _max_value
	if not _attribute_comp.attribute_value_changed.is_connected(_on_attribute_value_changed):
		_attribute_comp.attribute_value_changed.connect(_on_attribute_value_changed)

func _process(delta: float) -> void:
	# 处理自动回复
	if _regen_rate == 0.0:
		return
	set_current_value(_current_value + _regen_rate * delta)

func set_current_value(value: float) -> void:
	_current_value = clampf(value, 0.0, _max_value)
	value_changed.emit(_current_value, _max_value)

## 获取当前值
func get_current_value() -> float:
	return _current_value

## 获取最大值
func get_max_value() -> float:
	return _max_value

## 获取比例 (0.0 - 1.0)
func get_ratio() -> float:
	if _max_value == 0: return 0.0
	return clampf(_current_value / _max_value, 0.0, 1.0)

func _on_attribute_value_changed(attribute_id : StringName, value: float) -> void:
	match attribute_id:
		max_value_id:
			max_value_changed.emit(value)
		regen_rate_id:
			regen_rate_changed.emit(value)

