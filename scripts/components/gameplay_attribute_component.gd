extends Node
class_name GameplayAttributeComponent

## 属性组件
## 管理角色的属性系统（攻击力、防御力等）

## 如果传入的属性集不为空，则使用传入的属性集，否则使用默认的属性集
@export var _active_sets: Array[GameplayAttributeSet] = []

# ID -> Instance
var _attributes: Dictionary[StringName, GameplayAttributeInstance] = {}
# 记录活跃的 Set，用于触发依赖逻辑

## 当前等级（用于计算 ScalableValue）
var current_level: int = 1 : set = _set_current_level

signal attribute_value_changed(id: StringName, new_val: float)
signal level_changed(old_level: int, new_level: int)

## 初始化属性组件
## [param] sets: Array[GameplayAttributeSet] 属性集数组
func initialize(sets: Array[GameplayAttributeSet] = []) -> void:
	if not sets.is_empty():
		_active_sets = sets.duplicate(true)
	# 1. 先注册所有属性 (此时属性实例尚未创建，无法互相读取)
	for atr_set in _active_sets:
		var new_instances = atr_set.instantiate_attributes()
		for id in new_instances:
			_register_instance(id, new_instances[id])
	# 2. 再处理依赖关系 (此时所有属性都已存在，可以互相读取)
	for atr_set in _active_sets:
		atr_set.resolve_dependencies(self)

# --- Public API ---

func get_value(id: StringName, default: float = 0.0) -> float:
	if not _attributes.has(id):
		push_warning("GameplayAttributeComponent: Attribute with id %s not found" % id)
		return default
	return _attributes[id].get_value()

func get_attribute(id: StringName) -> GameplayAttributeInstance:
	return _attributes.get(id, null)

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

func get_gameplay_attribute_component() -> GameplayAttributeComponent:
	return self

func _register_instance(id: StringName, instance: GameplayAttributeInstance) -> void:
	if has_attribute(id):
		push_warning("Attribute with id %s already registered" % id)
	_attributes[id] = instance
	
	# 设置实例的等级（用于 ScalableValue 计算）
	instance.current_level = current_level
	
	# 转发信号
	instance.value_changed.connect(func(old, new): 
		attribute_value_changed.emit(id, new)
		_handle_dependency(id, new)
	)

## 获取当前等级
func get_level() -> int:
	return current_level

## 设置等级（公共接口）
func set_level(level: int) -> void:
	_set_current_level(level)

## 提升等级
func level_up(level: int = 1) -> void:
	_set_current_level(current_level + level)

# --- 依赖处理 ---
func _handle_dependency(attr_id: StringName, new_val: float):
	# 这里加一个锁或者检查，防止循环依赖导致死循环
	# 简单的做法是：衍生属性的变化不应该再触发 _handle_dependency
	# 或者信任 AttributeSet 的设计是无环的 (DAG)

	# 通知所有 Set，看看有没有人关心这个属性的变化
	for set in _active_sets:
		set.on_attribute_changed(self, attr_id, new_val)

## 设置等级（会更新所有使用 ScalableValue 的属性）
func _set_current_level(level: int) -> void:
	if current_level == level: return
	var old_level = current_level
	current_level = max(1, level)
	
	# 更新所有使用 ScalableValue 的属性实例
	for instance in _attributes.values():
		if is_instance_valid(instance):
			instance.current_level = current_level
	
	level_changed.emit(old_level, current_level)
