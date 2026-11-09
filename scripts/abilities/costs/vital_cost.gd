extends AbilityCostBase
class_name VitalCost

## Configures a payment from a Vital on the caster.
@export var vital_id: StringName = &"mana"
@export var amount: float = 10.0
## If enabled, a positive remaining balance can be spent down to zero.
@export var allow_overdraft: bool = false

func _can_pay(_ability_comp: Node, instigator: Node) -> bool:
	var component: GameplayVitalAttributeComponent = _get_vital_component(instigator)
	return is_instance_valid(component) and component.can_spend(vital_id, amount, allow_overdraft)

func _try_pay(_ability_comp: Node, instigator: Node) -> bool:
	var component: GameplayVitalAttributeComponent = _get_vital_component(instigator)
	return is_instance_valid(component) and component.try_spend(vital_id, amount, allow_overdraft)

func _get_cost_description() -> String:
	return "消耗 %s: %.0f" % [vital_id, amount]

func _get_vital_component(instigator: Node) -> GameplayVitalAttributeComponent:
	if not is_instance_valid(instigator):
		return null
	return GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayAttributeComponent") as GameplayVitalAttributeComponent
