extends Node

## 战斗系统管理器（单例）
## 管理所有战斗相关的实体和组件

var _entities: Array[Node] = []

## 注册战斗实体
## [param] entity: Node 战斗实体节点
func register_entity(entity: Node) -> void:
	if entity not in _entities:
		_entities.append(entity)

## 注销战斗实体
## [param] entity: Node 战斗实体节点
func unregister_entity(entity: Node) -> void:
	_entities.erase(entity)

## 获取所有注册的实体
func get_all_entities() -> Array[Node]:
	return _entities.duplicate()

## 通过接口查询组件（鸭子类型）
## [param] entity: Node 实体节点
## [param] component_name: String 组件名称（如"HealthComponent"）
## [returns] Node 组件节点，如果不存在则返回null
static func get_component_by_interface(entity: Node, component_name: String) -> Node:
	if not is_instance_valid(entity):
		return null
	
	# 遍历所有子节点，查找具有指定方法的组件（鸭子类型）
	for child in entity.get_children():
		# 检查是否有对应的方法（鸭子类型检查）
		if child.has_method("get_" + component_name.to_lower().replace("component", "")):
			return child
		# 或者通过类名检查（如果定义了class_name）
		if child.get_script() and child.get_script().get_global_name() == component_name:
			return child
	
	return null

## 查询实体是否有指定组件
## [param] entity: Node 实体节点
## [param] component_name: String 组件名称
## [returns] bool 是否存在
static func has_component(entity: Node, component_name: String) -> bool:
	return get_component_by_interface(entity, component_name) != null

