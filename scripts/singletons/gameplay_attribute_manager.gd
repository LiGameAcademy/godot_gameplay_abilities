extends Node
class_name GameplayAttributeManager

## 属性管理器

var _attributes : Dictionary[StringName, GameplayAttribute] = {}

## 注册属性
## [param] attribute: GameplayAttribute 属性
func register_attribute(attribute: GameplayAttribute) -> void:
    if _attributes.has(attribute.attribute_id):
        push_warning("Attribute with id %s already registered" % attribute.attribute_id)
    _attributes[attribute.attribute_id] = attribute

## 注册多个属性
## [param] attributes: Array[GameplayAttribute] 属性数组
func register_attributes(attributes: Array[GameplayAttribute]) -> void:
    for attribute in attributes:
        register_attribute(attribute)

## 注销属性
## [param] attribute_id: StringName 属性ID
func unregister_attribute(attribute_id: StringName) -> void:
    if not has_attribute(attribute_id):
        push_warning("Attribute with id %s not found" % attribute_id)
        return
    _attributes.erase(attribute_id)

## 存在属性配置
func has_attribute(attribute_id: StringName) -> bool:
    return _attributes.has(attribute_id)

## 获取属性
## [param] attribute_id: StringName 属性ID
## [return] GameplayAttribute 属性，如果不存在则返回null
func get_attribute(attribute_id: StringName) -> GameplayAttribute:
    if not has_attribute(attribute_id):
        push_warning("Attribute with id %s not found" % attribute_id)
        return null
    return _attributes[attribute_id]

## 获取所有属性
## [return] Array[GameplayAttribute] 属性数组
func get_all_attributes() -> Array[GameplayAttribute]:
    return _attributes.values()