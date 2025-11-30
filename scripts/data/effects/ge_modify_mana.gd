extends GameplayEffect
class_name GE_ModifyMana

## 修改法力值效果

enum Operation {
	ADD,      ## 加法
	MULTIPLY, ## 乘法
}

@export var amount: float = 1.0
@export var operation: Operation = Operation.ADD

func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
	# 使用鸭子类型查询组件
	var mana_comp = GameplayAbilitySystem.get_component_by_interface(target, "ManaComponent")
	if not mana_comp:
		# 法力组件不存在时静默失败（某些单位可能没有法力）
		return
	
	match operation:
		Operation.ADD:
			var current_value = mana_comp.get_current_value()
			mana_comp.set_current_value(current_value + amount)
		Operation.MULTIPLY:
			var current_value = mana_comp.get_current_value()
			mana_comp.set_current_value(current_value * amount)

func _get_description() -> String:
	match operation:
		Operation.ADD:
			return "Add %s mana\n" % amount
		Operation.MULTIPLY:
			return "Multiply mana by %s%%\n" % (amount * 100.0)
	return "No description available.\n"

