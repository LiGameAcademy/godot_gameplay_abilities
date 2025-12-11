extends GameplayAbility
class_name PassiveAbility

## 被动技能数据
## 被动技能在学会时自动应用状态，遗忘时自动移除

func _on_learned(ability_comp: Node, status_comp: Node) -> void:
	if not is_instance_valid(ability_comp) or not is_instance_valid(status_comp): 
		return
	if not is_instance_valid(status_to_apply): 
		return
	
	# 应用状态（使用鸭子类型）
	if status_comp.has_method("apply_status"):
		var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
		status_comp.apply_status(status_to_apply, instigator)

func _on_forgotten(ability_comp: Node, status_comp: Node) -> void:
	if not is_instance_valid(ability_comp) or not is_instance_valid(status_comp): 
		return
	if not is_instance_valid(status_to_apply): 
		return
	
	# 移除状态（使用鸭子类型）
	if status_comp.has_method("remove_status"):
		status_comp.remove_status(status_to_apply.status_id)

func _can_cast(_ability_comp: Node, _target: Node, _context: Dictionary = {}) -> bool:
	return false  # 被动技能不能主动施放

func _commit_cast(_ability_comp: Node) -> bool:
	return false  # 被动技能不能提交施法

func _on_cast(_ability_comp: Node, _target: Node, _context: Dictionary = {}) -> void:
	push_warning("PassiveAbility: Cannot cast passive ability '%s'" % ability_id)

func _clear_cast(_ability_comp: Node, _target: Node) -> void:
	pass  # 被动技能不需要清除
