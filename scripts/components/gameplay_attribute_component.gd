extends Node
class_name GameplayAttributeComponent

# ID -> Instance
var _attributes: Dictionary[StringName, GameplayAttributeInstance] = {}
# 记录活跃的 Set，用于触发依赖逻辑
var _active_sets: Array[GameplayAttributeSet] = []
var _active_vitals: Dictionary[StringName, GameplayVital] = {}

signal attribute_value_changed(id: StringName, new_val: float)
signal vital_value_changed(id, current, max, percent)
signal vital_depleted(id)

func _ready() -> void:
	set_process(true) # 确保开启

func _process(delta: float) -> void:
	# 统一驱动所有 Vital 的回复
	for vital in _active_vitals.values():
		vital.process_regen(delta)

func initialize(sets: Array[GameplayAttributeSet], vitals: Array[GameplayVitalDefinition]) -> void:
	_active_sets = sets.duplicate(true)
	# 1. 先注册所有属性 (此时属性实例尚未创建，无法互相读取)
	for set in _active_sets:
		var new_instances = set.instantiate_attributes()
		for id in new_instances:
			_register_instance(id, new_instances[id])
	# 2. 再处理依赖关系 (此时所有属性都已存在，可以互相读取)
	for set in _active_sets:
		set.resolve_dependencies(self)

	_initialize_vitals(vitals)

# --- Public API ---

func get_value(id: StringName, default: float = 0.0) -> float:
	if _attributes.has(id):
		return _attributes[id].get_value()
	return default

func set_base_value(id: StringName, val: float):
	if _attributes.has(id):
		_attributes[id].base_value = val

func add_modifier(mod: GameplayAttributeModifier):
	if _attributes.has(mod.attribute_id):
		_attributes[mod.attribute_id].add_modifier(mod)

func remove_modifier(mod: GameplayAttributeModifier):
	if _attributes.has(mod.attribute_id):
		_attributes[mod.attribute_id].remove_modifier(mod)

func has_attribute(id: StringName) -> bool:
	return _attributes.has(id)

func _register_instance(id: StringName, instance: GameplayAttributeInstance) -> void:
	if has_attribute(id):
		push_warning("Attribute with id %s already registered" % id)
	_attributes[id] = instance
	# 转发信号
	instance.value_changed.connect(func(old, new): 
		attribute_value_changed.emit(id, new)
		_handle_dependency(id, new)
	)

# --- API: 操作 Vital ---

func has_vital(vital_id: StringName) -> bool:
	return _active_vitals.has(vital_id)

func get_vital(vital_id: StringName) -> GameplayVital:
	return _active_vitals.get(vital_id, null)

func get_vital_value(vital_id: StringName) -> float:
	if has_vital(vital_id):
		return get_vital(vital_id).current_value
	return 0.0

## 是否有足够的Vital
func has_sufficient_vital(vital_id: StringName, amount: float) -> bool:
	return get_vital_value(vital_id) >= amount

func get_vital_percent(vital_id: StringName) -> float:
	if has_vital(vital_id):
		return get_vital(vital_id).get_percent()
	return 0.0

func modify_vital(vital_id: StringName, amount: float) -> bool:
	if not has_sufficient_vital(vital_id, amount):
		return false
	get_vital(vital_id).modify_value(amount)
	return true

# --- 依赖处理 ---
func _handle_dependency(attr_id: StringName, new_val: float):
	# 这里加一个锁或者检查，防止循环依赖导致死循环
	# 简单的做法是：衍生属性的变化不应该再触发 _handle_dependency
	# 或者信任 AttributeSet 的设计是无环的 (DAG)

	# 通知所有 Set，看看有没有人关心这个属性的变化
	for set in _active_sets:
		set.on_attribute_changed(self, attr_id, new_val)

func _initialize_vitals(vital_definitions: Array[GameplayVitalDefinition]) -> void:
	_active_vitals.clear()
	
	for def in vital_definitions:
		if not def: continue
		
		# 检查依赖的属性是否存在
		if not has_attribute(def.max_value_attribute):
			push_warning("Vital [%s] skipped: Missing max attribute [%s]" % [def.vital_id, def.max_value_attribute])
			continue
			
		# 创建运行时实例 (Template -> Instance)
		var vital_instance = GameplayVital.new(def, self)
		_active_vitals[def.vital_id] = vital_instance
		
		# 转发信号
		vital_instance.value_changed.connect(func(c, m, p): vital_value_changed.emit(def.vital_id, c, m, p))
		vital_instance.depleted.connect(func(): vital_depleted.emit(def.vital_id))
