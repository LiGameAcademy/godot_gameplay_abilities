extends GameplayAbilityFeature
class_name CostFeature

@export_group("Cost Settings")
## A single cost can use any implementation. Multiple costs must be built-in VitalCost resources.
@export var costs: Array[AbilityCostBase] = []

func _init() -> void:
	super("CostFeature")

func can_activate(_ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	return _process_costs(context, false)

func try_pay(_ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	return _process_costs(context, true)

func _process_costs(context: Dictionary, pay: bool) -> bool:
	if context.get("skip_cost", false):
		return true
	var ability_comp: Node = context.get("ability_component") as Node
	var instigator: Node = context.get("instigator") as Node
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		return false

	var valid_costs: Array[AbilityCostBase] = []
	for cost: AbilityCostBase in costs:
		if is_instance_valid(cost):
			valid_costs.append(cost)
	if valid_costs.is_empty():
		return true
	if valid_costs.size() == 1:
		var cost: AbilityCostBase = valid_costs[0]
		return cost.try_pay(ability_comp, instigator) if pay else cost.can_pay(ability_comp, instigator)

	var component: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(
		instigator, "GameplayAttributeComponent", false) as GameplayVitalAttributeComponent
	if not is_instance_valid(component):
		return false
	var remaining: Dictionary[StringName, float] = {}
	for cost: AbilityCostBase in valid_costs:
		var vital_cost: VitalCost = cost as VitalCost
		if vital_cost == null or vital_cost.get_script() != VitalCost:
			return false
		if not is_finite(vital_cost.amount) or vital_cost.amount < 0.0:
			return false
		var id: StringName = vital_cost.vital_id
		if not component.has_vital(id):
			return false
		var balance: float = remaining.get(id, component.get_vital_value(id))
		if balance < vital_cost.amount and not (vital_cost.allow_overdraft and balance > 0.0):
			return false
		remaining[id] = maxf(0.0, balance - vital_cost.amount)
	if not pay:
		return true

	var payments: Dictionary[StringName, float] = {}
	for id: StringName in remaining:
		payments[id] = component.get_vital_value(id) - remaining[id]
	return component.try_spend_batch(payments)
