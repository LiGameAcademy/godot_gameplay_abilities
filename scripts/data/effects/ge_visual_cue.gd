extends GameplayEffect
class_name GE_VisualCue

## 视觉提示效果
## 仅用于触发 Cue，不执行任何逻辑效果
## 适用于：光环特效、持续视觉反馈等

func _apply(_target: Node, _instigator: Node, _context: Dictionary) -> void:
	# 不执行任何逻辑，只触发 Cue（由基类处理）
	pass

func _get_description() -> String:
	return "视觉提示效果"
