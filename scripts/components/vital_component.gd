extends Node
class_name VitalComponent

## Vital 组件
## 管理实体的所有 Vital 实例（生命值、法力值等）
## 采用组合模式：VitalComponent 管理多个 Vital 实例

@export var _attribute_comp: GameplayAttributeComponent

## Vital 实例字典
var _vitals: Dictionary[StringName, Vital] = {}

## 注册 Vital 实例
## [param] vital: Vital Vital 实例
func register_vital(vital: Vital) -> void:
	if not is_instance_valid(vital):
		push_error("VitalComponent: Cannot register invalid vital!")
		return
	
	if _vitals.has(vital.vital_id):
		push_warning("VitalComponent: Vital %s already exists, replacing..." % vital.vital_id)
	
	_vitals[vital.vital_id] = vital

## 获取 Vital 实例
## [param] vital_id: StringName Vital ID
## [return] Vital Vital 实例，如果不存在则返回null
func get_vital(vital_id: StringName) -> Vital:
	return _vitals.get(vital_id, null)

## 检查是否有指定的 Vital
## [param] vital_id: StringName Vital ID
## [return] bool 是否存在
func has_vital(vital_id: StringName) -> bool:
	return _vitals.has(vital_id)

## 移除 Vital 实例
## [param] vital_id: StringName Vital ID
func remove_vital(vital_id: StringName) -> void:
	if _vitals.has(vital_id):
		_vitals.erase(vital_id)

## 获取所有 Vital 实例
## [return] Dictionary[StringName, Vital] Vital 实例字典
func get_all_vitals() -> Dictionary[StringName, Vital]:
	return _vitals.duplicate()

func _ready() -> void:
	if not is_instance_valid(_attribute_comp):
		push_error("%s: GameplayAttributeComponent is not set!" % self.name)

func _process(delta: float) -> void:
	# 处理所有 Vital 的自动恢复
	for vital in _vitals.values():
		if is_instance_valid(vital):
			vital.process_regen(delta)

## ========== 向后兼容接口 ==========
## 以下接口用于向后兼容，提供类似旧组件的访问方式

## 获取生命值 Vital（向后兼容）
## [return] HealthVital 生命值 Vital，如果不存在则返回null
func get_health_vital() -> HealthVital:
	return get_vital(&"health") as HealthVital

## 获取法力值 Vital（向后兼容）
## [return] ManaVital 法力值 Vital，如果不存在则返回null
func get_mana_vital() -> ManaVital:
	return get_vital(&"mana") as ManaVital

## 检查是否有生命值 Vital（向后兼容）
## [return] bool 是否存在
func has_health() -> bool:
	return has_vital(&"health")

## 检查是否有法力值 Vital（向后兼容）
## [return] bool 是否存在
func has_mana() -> bool:
	return has_vital(&"mana")
