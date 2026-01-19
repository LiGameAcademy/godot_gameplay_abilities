extends GameplayAbilityFeature
class_name CostFeature

@export_group("Cost Settings")
## 技能消耗器数组（支持多种消耗类型）
@export var costs: Array[AbilityCostBase] = []

func _init() -> void:
	super("CostFeature")

#func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	#try_pay(ability, context)

func can_activate(ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	if context.get("skip_cost", false):
		return true
	
	var ability_comp = context.get("ability_component", null)
	var instigator = context.get("instigator", null)

	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		push_warning("can not found ability_component or instigator")
		return false

	# 检查是否可以支付所有消耗
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		if not cost.can_pay(ability_comp, instigator):
			return false

	return true

func try_pay(ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	if context.get("skip_cost", false):
		return true
	
	var ability_comp = context.get("ability_component", null)
	var instigator = context.get("instigator", null)
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		push_warning("can not found ability_component or instigator")
		return false

	# 遍历所有消耗器，检查并消耗资源
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		# 尝试支付消耗
		if not cost.try_pay(ability_comp, instigator):
			return false
	return true
