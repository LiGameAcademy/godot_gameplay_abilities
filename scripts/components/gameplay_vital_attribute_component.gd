extends GameplayAttributeComponent
class_name GameplayVitalAttributeComponent

## Vital 属性组件
## 继承自 GameplayAttributeComponent，扩展 Vitals 管理功能
## 提供完整的属性系统和生命值系统集成

## 如果传入的Vital不为空，则使用传入的Vital，否则使用默认的Vital
@export var _vitals: Array[GameplayVital] = []

## 活跃的 Vital 实例 { vital_id: GameplayVital }
var _active_vitals: Dictionary[StringName, GameplayVital] = {}

## 信号
signal vital_value_changed(vital_id: StringName, current: float, max: float, percent: float)
signal vital_depleted(vital_id: StringName)

func _ready() -> void:
	# 确保开启 process 以处理 Vital 恢复
	set_process(true)

func _process(delta: float) -> void:
	# 统一驱动所有 Vital 的回复
	for vital in _active_vitals.values():
		if is_instance_valid(vital):
			vital.process_regen(delta)

## 初始化组件（扩展父类方法）
## [param] sets: Array[GameplayAttributeSet] 属性集数组
## [param] vitals: Array[GameplayVital] Vital 数组
func initialize(sets: Array[GameplayAttributeSet] = [], vitals: Array[GameplayVital] = []) -> void:
	# 先初始化属性系统
	super(sets)
	
	# 再初始化 Vitals
	_initialize_vitals(vitals)

## 初始化 Vitals
## [param] vitals: Array[GameplayVital] Vital 模板数组
func _initialize_vitals(vitals: Array[GameplayVital]) -> void:
	if not vitals.is_empty():
		_vitals = vitals.duplicate(true)
	
	_active_vitals.clear()
	
	for vital_template in _vitals:
		if not is_instance_valid(vital_template):
			continue
		
		var def = vital_template.definition
		if not def:
			continue
		
		# 检查依赖的属性是否存在
		if not has_attribute(def.max_value_attribute):
			push_warning("GameplayVitalAttributeComponent: Vital [%s] skipped: Missing max attribute [%s]" % [def.vital_id, def.max_value_attribute])
			continue
		
		# 创建运行时实例 (Template -> Instance)
		var vital_instance = vital_template.duplicate(true)
		vital_instance._owner_comp = self
		
		# 初始化数值
		vital_instance._update_cached_max()
		vital_instance.current_value = vital_instance._cached_max
		
		# 连接属性变化信号（确保 Vital 能响应属性变化）
		if attribute_value_changed.is_connected(vital_instance._on_attribute_changed):
			attribute_value_changed.disconnect(vital_instance._on_attribute_changed)
		attribute_value_changed.connect(vital_instance._on_attribute_changed)
		
		# 注册实例
		_active_vitals[def.vital_id] = vital_instance
		
		# 转发信号
		vital_instance.value_changed.connect(_on_vital_value_changed.bind(def.vital_id))
		vital_instance.depleted.connect(_on_vital_depleted.bind(def.vital_id))

# --- API: 操作 Vital ---

## 检查是否有指定的 Vital
## [param] vital_id: StringName Vital ID
## [return] bool 是否存在
func has_vital(vital_id: StringName) -> bool:
	return _active_vitals.has(vital_id)

## 获取 Vital 实例
## [param] vital_id: StringName Vital ID
## [return] GameplayVital Vital 实例，如果不存在则返回 null
func get_vital(vital_id: StringName) -> GameplayVital:
	return _active_vitals.get(vital_id, null)

## 获取 Vital 当前值
## [param] vital_id: StringName Vital ID
## [return] float 当前值，如果不存在则返回 0.0
func get_vital_value(vital_id: StringName) -> float:
	if has_vital(vital_id):
		return get_vital(vital_id).current_value
	return 0.0

## 检查是否有足够的 Vital
## [param] vital_id: StringName Vital ID
## [param] amount: float 需要的数量
## [return] bool 是否有足够的 Vital
func has_sufficient_vital(vital_id: StringName, amount: float) -> bool:
	return get_vital_value(vital_id) >= amount

## 获取 Vital 百分比
## [param] vital_id: StringName Vital ID
## [return] float 百分比（0.0-1.0），如果不存在则返回 0.0
func get_vital_percent(vital_id: StringName) -> float:
	if has_vital(vital_id):
		return get_vital(vital_id).get_percent()
	return 0.0

## 修改 Vital 值
## [param] vital_id: StringName Vital ID
## [param] amount: float 修改量（正数为增加，负数为减少）
## [return] bool 是否成功修改
func modify_vital(vital_id: StringName, amount: float) -> bool:
	if not has_vital(vital_id):
		return false
	
	if amount < 0 and not has_sufficient_vital(vital_id, -amount):
		return false
	
	get_vital(vital_id).modify_value(amount)
	return true

## 注册 Vital 实例（运行时动态添加）
## [param] vital: GameplayVital Vital 实例
## [return] bool 是否成功注册
func register_vital(vital: GameplayVital) -> bool:
	if not is_instance_valid(vital):
		push_warning("GameplayVitalAttributeComponent: Invalid vital instance")
		return false
	
	var def = vital.definition
	if not def:
		push_warning("GameplayVitalAttributeComponent: Vital missing definition")
		return false
	
	# 检查依赖的属性是否存在
	if not has_attribute(def.max_value_attribute):
		push_warning("GameplayVitalAttributeComponent: Vital [%s] skipped: Missing max attribute [%s]" % [def.vital_id, def.max_value_attribute])
		return false
	
	# 设置属性组件引用
	vital._owner_comp = self
	
	# 初始化 Vital（更新最大值等）
	vital._update_cached_max()
	vital.current_value = vital._cached_max
	
	# 连接属性变化信号（确保 Vital 能响应属性变化）
	if attribute_value_changed.is_connected(vital._on_attribute_changed):
		attribute_value_changed.disconnect(vital._on_attribute_changed)
	attribute_value_changed.connect(vital._on_attribute_changed)
	
	# 注册实例
	_active_vitals[def.vital_id] = vital
	
	# 转发信号
	vital.value_changed.connect(_on_vital_value_changed.bind(def.vital_id))
	vital.depleted.connect(_on_vital_depleted.bind(def.vital_id))
	
	return true

## Vital 值变化回调
## [param] vital_id: StringName Vital ID
## [param] current: float 当前值
## [param] max: float 最大值
## [param] percent: float 百分比
func _on_vital_value_changed(current: float, max: float, percent: float, vital_id: StringName) -> void:
	vital_value_changed.emit(vital_id, current, max, percent)

## Vital 耗尽回调
## [param] vital_id: StringName Vital ID
func _on_vital_depleted(vital_id: StringName) -> void:
	vital_depleted.emit(vital_id)
