extends Resource
class_name GameplayVital 

## Vital 配置字段（原 Definition 的字段，现在直接内嵌）
@export_group("Identity")
@export var vital_id: StringName = &""
@export var display_name: String = ""

@export_group("Attribute Dependencies")
## 决定最大值的属性 ID (如 "health", "mana")
@export var max_value_attribute: StringName = &""
## 决定恢复速度的属性 ID (如 "health_regen", "mana_regen")，留空则不自动恢复
@export var regen_rate_attribute: StringName = &""

# --- 运行时数据 ---

var _owner_comp: GameplayAttributeComponent

var current_value: float = 0.0
var _cached_max: float = 0.0

# --- 信号 ---
signal value_changed(current: float, max: float, percent: float)
signal depleted() # 归零
signal full()     # 满值

# --- 初始化 ---
func _init(p_comp: GameplayAttributeComponent = null) -> void:
	_owner_comp = p_comp
	
	# 初始化数值
	_update_cached_max()
	current_value = _cached_max
	
	# 监听属性变化 (用于动态调整最大值)
	if _owner_comp:
		_owner_comp.attribute_value_changed.connect(_on_attribute_changed)

# --- 逻辑 ---
func process_regen(delta: float):
	if regen_rate_attribute == &"": return
	
	var rate = _owner_comp.get_value(regen_rate_attribute)
	if rate != 0:
		modify_value(rate * delta)

func modify_value(amount: float):
	_update_cached_max()
	var old_val = current_value
	current_value = clampf(current_value + amount, 0.0, _cached_max)
	
	if old_val != current_value:
		value_changed.emit(current_value, _cached_max, get_percent())
		
		if current_value == 0 and old_val > 0:
			depleted.emit()
		elif current_value == _cached_max and old_val < _cached_max:
			full.emit()

func get_percent() -> float:
	return current_value / _cached_max if _cached_max > 0 else 0.0

func _update_cached_max():
	if _owner_comp:
		_cached_max = _owner_comp.get_value(max_value_attribute)

func _on_attribute_changed(attr_id: StringName, val: float):
	if attr_id == max_value_attribute:
		_update_cached_max()
		# 可选策略：最大值变大时，当前值是否按比例增加？还是保持不变？
		# 这里采用：保持数值，截断上限
		if current_value > _cached_max:
			current_value = _cached_max
			value_changed.emit(current_value, _cached_max, get_percent())
