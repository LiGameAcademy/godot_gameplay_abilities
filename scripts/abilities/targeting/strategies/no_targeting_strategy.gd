extends TargetingStrategy
class_name NoTargetingStrategy

## 无目标策略
## 适用于：战吼、光环、被动触发等不需要目标的技能
##
## 注意：即使不需要目标，技能仍然可能通过 caster_effects 对自己生效

func _resolve_targets(_instigator: Node, _input_target: Node, _context: Dictionary) -> Array[Node]:
	# 明确返回空列表，表示不需要目标
	return []

func _get_description() -> String:
	return "No Target (无目标)"

