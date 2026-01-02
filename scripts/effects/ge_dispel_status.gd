extends GameplayEffect
class_name GE_DispelStatus

## 这个效果要移除哪些标签？
@export var tags_to_remove: Array[StringName] = [&"magic", &"debuff"]


func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
	var status_component : GameplayStatusComponent = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not status_component:
		push_error("GE_DispelStatus: Target %s has no GameplayStatusComponent." % target.name)
		return
	
	status_component.remove_statuses_by_tags(tags_to_remove)
