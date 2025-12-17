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
signal value_changed(current: float, max: float, percent: float, is_regen: bool)
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
## 初始化 Vital 实例
## 绑定到指定的属性组件并初始化数值
## [param] p_comp: GameplayAttributeComponent 属性组件引用
func initialize(p_comp: GameplayAttributeComponent) -> void:
	_owner_comp = p_comp
	# 初始化数值（必须在设置 _owner_comp 之后）
	_update_cached_max()
	current_value = _cached_max
	# 连接属性变化信号（确保 Vital 能响应属性变化）
	if is_instance_valid(_owner_comp):
		if _owner_comp.attribute_value_changed.is_connected(_on_attribute_changed):
			_owner_comp.attribute_value_changed.disconnect(_on_attribute_changed)
		_owner_comp.attribute_value_changed.connect(_on_attribute_changed)

## 创建运行时实例
## 从模板创建独立的 Vital 实例，并绑定到指定的属性组件
## [param] p_comp: GameplayAttributeComponent 属性组件引用
## [return] GameplayVital 新创建的 Vital 实例
func create_instance(p_comp: GameplayAttributeComponent) -> GameplayVital:
	# 先复制模板创建实例（避免修改模板）
	var instance: GameplayVital = duplicate(true)
	# 使用公共方法初始化实例（避免直接访问私有成员）
	instance.initialize(p_comp)
	return instance

func process_regen(delta: float):
	if regen_rate_attribute == &"": return
	
	var rate = _owner_comp.get_value(regen_rate_attribute)
	if rate != 0:
		# 自动回复时传入 is_regen=true，订阅者可以根据此参数决定是否处理
		modify_value(rate * delta, true)

## 修改值
## [param] amount: float 修改量（正数为增加，负数为减少）
## [param] is_regen: bool 是否为自动回复（默认 false）
## 注意：depleted 和 full 信号始终会发射（如果条件满足）
func modify_value(amount: float, is_regen: bool = false) -> void:
	_update_cached_max()
	var old_val = current_value
	current_value = clampf(current_value + amount, 0.0, _cached_max)
	
	if old_val == current_value:
		return
	
	# 始终发射 value_changed 信号，但传入 is_regen 参数，让订阅者决定是否处理
	value_changed.emit(current_value, _cached_max, get_percent(), is_regen)
	
	# 重要事件信号始终发射（即使自动回复时）
	if current_value == 0 and old_val > 0:
		depleted.emit()
	elif current_value >= _cached_max and old_val < _cached_max:
		full.emit()

func get_percent() -> float:
	return current_value / _cached_max if _cached_max > 0 else 0.0

## 获取最大值
## [return] float 当前的最大值
func get_max_value() -> float:
	return _cached_max

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
			# 属性变化导致的更新，不是自动回复
			value_changed.emit(current_value, _cached_max, get_percent(), false)
