extends Node
## Exercises payment and HealthVital damage without Ability or Status.

func _ready() -> void:
	var attribute_set: GameplayAttributeSet = GameplayAttributeSet.new()
	for id: StringName in [&"max_mana", &"max_health"]:
		var definition: GameplayAttribute = GameplayAttribute.new()
		definition.attribute_id = id
		attribute_set.attributes[definition] = 10.0
	var mana: GameplayVital = GameplayVital.new()
	mana.vital_id = &"mana"
	mana.max_value_attribute = &"max_mana"
	var health: HealthVital = HealthVital.new()
	health.vital_id = &"health"
	health.max_value_attribute = &"max_health"
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	add_child(component)
	component.initialize([attribute_set], [mana, health])
	var paid: bool = component.try_spend(&"mana", 3.0)
	var rejected: bool = not component.try_spend(&"mana", 8.0)
	var runtime_health: HealthVital = component.get_vital(&"health") as HealthVital
	var hit: DamageInfo = DamageInfo.new(self, self, 2.0)
	hit.final_damage = 2.0
	var applied: float = runtime_health.apply_damage(hit, self)
	if not paid or not rejected or component.get_vital_value(&"mana") != 7.0 \
			or applied != 2.0 or component.get_vital_value(&"health") != 8.0:
		push_error("Vital host did not preserve the payment and damage boundaries")
		get_tree().quit.call_deferred(1)
		return
	print("PASS: Attribute + Vital host")
	get_tree().quit.call_deferred(0)
