extends Node
## Verifies the module installed in a host with no gameplay Autoloads.

func _ready() -> void:
	var definition: GameplayAttribute = GameplayAttribute.new()
	definition.attribute_id = &"power"
	var attribute_set: GameplayAttributeSet = GameplayAttributeSet.new()
	attribute_set.attributes[definition] = 10.0
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	add_child(component)
	component.initialize([attribute_set])
	var modifier: GameplayAttributeModifier = GameplayAttributeModifier.new(
		&"power", 3.0, GameplayAttributeModifier.ModifierType.ADD
	)
	var initial: float = component.get_value(&"power")
	component.add_modifier(modifier)
	var modified: float = component.get_value(&"power")
	component.remove_modifier(modifier)
	if initial != 10.0 or modified != 13.0 or component.get_value(&"power") != 10.0:
		push_error("Attribute-only host did not apply and remove the modifier")
		get_tree().quit.call_deferred(1)
		return
	print("PASS: Attribute-only host")
	get_tree().quit.call_deferred(0)
