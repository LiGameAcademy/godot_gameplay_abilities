extends Node

## 游戏技能系统管理器（单例）
## 管理所有战斗相关的实体和组件，提供组件查询接口

## 通过接口查询组件（获取组件方法或节点名，鸭子类型）
## [param] entity: Node 实体节点
## [param] component_name: String 组件名称（如"GameplayAttributeComponent"）
## [returns] Node 组件节点，如果不存在则返回null
## Optional lookups can disable diagnostics for targets without the component.
func get_component_by_interface(entity: Node, component_name: String, report_missing: bool = true) -> Node:
	return GameplayComponentLookup.find(entity, component_name, report_missing)
