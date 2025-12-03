extends Node

## 游戏技能系统管理器（单例）
## 管理所有战斗相关的实体和组件

var attribute_manager: GameplayAttributeManager = GameplayAttributeManager.new()
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

## 通过接口查询组件（获取组件方法或子节点名，鸭子类型）
## [param] entity: Node 实体节点
## [param] component_name: String 组件名称（如"HealthComponent"）
## [returns] Node 组件节点，如果不存在则返回null
func get_component_by_interface(entity: Node, component_name: String) -> Node:
	if not is_instance_valid(entity):
		return null
	
	var method_name : String = "get_" + component_name.to_snake_case()
	if entity.has_method(method_name):
		return entity.call(method_name)
	elif entity.has_node(component_name):
		return entity.get_node(component_name)
	
	# 遍历所有子节点，查找具有指定方法的组件（鸭子类型）
	for child in entity.get_children():
		# 检查是否有对应的方法（鸭子类型检查）
		if child.has_method(method_name):
			return child

	return null

## 查询实体是否有指定组件
## [param] entity: Node 实体节点
## [param] component_name: String 组件名称
## [returns] bool 是否存在
func has_component(entity: Node, component_name: String) -> bool:
	return get_component_by_interface(entity, component_name) != null
