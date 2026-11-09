extends Node
class_name GameplayAttributeComponent

## 游戏性属性组件
## 管理角色的属性系统（攻击力、防御力等）

## 如果传入的属性集不为空，则使用传入的属性集
@export var _active_sets: Array[GameplayAttributeSet] = []
# ID -> Instance（运行时实例）
var _attributes: Dictionary[StringName, GameplayAttributeInstance] = {}
var _dependency_path: Array[StringName] = []
var _pending_changes: Dictionary[StringName, float] = {}
var _initializing: bool = false
var _publishing_changes: bool = false

## Publishes the final value after synchronous dependency updates have settled.
signal attribute_value_changed(id: StringName, new_val: float)

## 初始化属性组件
## [param] sets: Array[GameplayAttributeSet] 属性集数组
func initialize(sets: Array[GameplayAttributeSet] = []) -> void:
	_initializing = true
	for id: StringName in _attributes:
		_attributes[id].value_changed.disconnect(_on_instance_value_changed.bind(id))
	_attributes.clear()
	if not sets.is_empty():
		_active_sets = sets.duplicate(true)
	
	# 1. 先注册所有属性 (此时属性实例尚未创建，无法互相读取)
	for attr_set in _active_sets:
		var new_instances : Dictionary[StringName, GameplayAttributeInstance] = attr_set.instantiate_attributes()
		for id in new_instances:
			_register_instance(id, new_instances[id])

	# 2. 再处理依赖关系 (此时所有属性都已存在，可以互相读取)
	for atr_set in _active_sets:
		atr_set.resolve_dependencies(self)
	_initializing = false
	_publish_changes()

## 获取属性值
## [param] id: StringName 属性ID
## [param] default: float 默认值（如果属性不存在）
## [return] float 属性值
func get_value(id: StringName, default: float = 0.0) -> float:
	if not has_attribute(id):
		push_warning("GameplayAttributeComponent: Attribute with id %s not found" % id)
		return default
	return _attributes[id].get_value()

## 获取属性实例
## [param] id: StringName 属性ID
## [return] GameplayAttributeInstance 属性实例（如果不存在返回 null）
func get_attribute(id: StringName) -> GameplayAttributeInstance:
	return _attributes.get(id, null)

## 设置基础值
## [param] id: StringName 属性ID
## [param] val: float 新的基础值
func set_base_value(id: StringName, val: float) -> bool:
	if has_attribute(id):
		var instance: GameplayAttributeInstance = _attributes[id]
		if instance.base_value != val and _is_dependency_cycle(id):
			return false
		instance.base_value = val
		return true
	push_warning("AttributeComponent: can not set base value: %s" %id)
	return false

## 检查属性是否存在
## [param] id: StringName 属性ID
## [return] bool 是否存在
func has_attribute(id: StringName) -> bool:
	return _attributes.has(id)

## 添加属性修改器
## [param] mod: GameplayAttributeModifier 修改器实例
func add_modifier(mod: GameplayAttributeModifier) -> void:
	if is_instance_valid(mod) and _attributes.has(mod.attribute_id):
		_attributes[mod.attribute_id].add_modifier(mod)

## 移除属性修改器
## [param] mod: GameplayAttributeModifier 修改器实例
func remove_modifier(mod: GameplayAttributeModifier) -> void:
	for instance: GameplayAttributeInstance in _attributes.values():
		instance.remove_modifier(mod)

## 根据 source_id 批量移除属性修改器
## [param] source_id: StringName 来源ID
func remove_modifiers_by_source(source_id: StringName) -> void:
	if source_id.is_empty():
		return

	# 遍历所有属性实例，移除匹配的修改器
	for attribute_id in _attributes.keys():
		var instance = _attributes[attribute_id]
		if is_instance_valid(instance):
			instance.remove_modifiers_by_source(source_id)

## 注册属性实例（内部方法）
## [param] id: StringName 属性ID
## [param] instance: GameplayAttributeInstance 属性实例
func _register_instance(id: StringName, instance: GameplayAttributeInstance) -> bool:
	if has_attribute(id):
		push_warning("Attribute with id %s already registered" % id)
		return false
	_attributes[id] = instance
	# 转发信号：当实例值变化时，组件也发出信号
	instance.value_changed.connect(_on_instance_value_changed.bind(id))
	return true

func _on_instance_value_changed(old_value: float, new_value: float, id: StringName) -> void:
	if not _pending_changes.has(id):
		_pending_changes[id] = old_value
	# Direct instance writes have already happened. Stop their recursive propagation.
	if _is_dependency_cycle(id):
		return
	_dependency_path.append(id)
	_handle_dependency(id, new_value)
	_dependency_path.pop_back()
	_publish_changes()

func _is_dependency_cycle(id: StringName) -> bool:
	if not _dependency_path.has(id):
		return false
	var path: PackedStringArray = PackedStringArray(_dependency_path)
	path.append(id)
	push_warning("GameplayAttributeComponent: attribute dependency cycle stopped: %s" % " -> ".join(path))
	return true

func _publish_changes() -> void:
	if _initializing or _publishing_changes or not _dependency_path.is_empty():
		return

	_publishing_changes = true
	while not _pending_changes.is_empty():
		var id: StringName = _pending_changes.keys()[0]
		var old_value: float = _pending_changes[id]
		_pending_changes.erase(id)
		var instance: GameplayAttributeInstance = get_attribute(id)
		if is_instance_valid(instance):
			var value: float = instance.get_value()
			if not is_equal_approx(old_value, value):
				attribute_value_changed.emit(id, value)
	_publishing_changes = false

## 处理依赖关系
## [param] attr_id: StringName 变化的属性ID
## [param] new_val: float 新值
func _handle_dependency(attr_id: StringName, new_val: float) -> void:
	# 通知所有 Set，看看有没有人关心这个属性的变化
	for attribute_set in _active_sets:
		attribute_set.on_attribute_changed(self, attr_id, new_val)
