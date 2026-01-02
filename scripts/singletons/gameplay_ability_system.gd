extends Node

## 游戏技能系统管理器（单例）
## 管理所有战斗相关的实体和组件，提供组件查询接口

## 通过接口查询组件（获取组件方法或节点名，鸭子类型）
## [param] entity: Node 实体节点
## [param] component_name: String 组件名称（如"GameplayAttributeComponent"）
## [returns] Node 组件节点，如果不存在则返回null
func get_component_by_interface(entity: Node, component_name: String) -> Node:
	if not is_instance_valid(entity):
		push_error("AbilitySystem: entity is not valid!")
		return null
	
	var method_name : String = "get_" + component_name.to_snake_case()
	if entity.has_method(method_name):
		return entity.call(method_name)

	if entity.has_method("get_component"):
		return entity.get_component(component_name)

	if entity.has_node(component_name):
		return entity.get_node(component_name)
	
	push_error("AbilitySystem: can not found component name: %s !" % component_name)
	return null
