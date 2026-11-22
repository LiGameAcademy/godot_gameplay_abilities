extends RefCounted
class_name GameplayComponentLookup
## Resolves a component on an explicitly supplied entity without an Autoload.

static func find(entity: Node, component_name: String, report_missing: bool = true) -> Node:
	if not is_instance_valid(entity):
		if report_missing:
			push_error("AbilitySystem: entity is not valid!")
		return null

	var method_name: String = "get_" + component_name.to_snake_case()
	if entity.has_method(method_name):
		return entity.call(method_name) as Node
	if entity.has_method("get_component"):
		return entity.call(&"get_component", component_name) as Node

	var component: Node = entity.get_node_or_null(NodePath(component_name))
	if component == null and report_missing:
		push_error("AbilitySystem: can not found component name: %s !" % component_name)
	return component
