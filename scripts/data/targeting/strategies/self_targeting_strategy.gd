extends TargetingStrategy
class_name SelfTargetingStrategy

## 自身目标策略
## 适用于：自身Buff、治疗自己、护盾等

func _resolve_targets(instigator: Node, _input_target: Node, _context: Dictionary) -> Array[Node]:
	var targets: Array[Node] = []
	if is_instance_valid(instigator):
		targets.append(instigator)
	return targets

func _get_description() -> String:
	return "Self (施法者自己)"
