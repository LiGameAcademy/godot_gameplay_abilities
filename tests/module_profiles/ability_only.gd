extends Node
## Exercises a custom execution tree and independent cooldowns without Autoloads.

class CommitAction extends BTAction:
	func _tick(instance: BTInstance, _delta: float) -> int:
		var ability: GameplayAbilityInstance = instance.get_var("ability_instance") as GameplayAbilityInstance
		var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
		cooldown.start_cooldown(ability)
		return Status.SUCCESS

class Caster extends Node:
	var abilities: GameplayAbilityComponent
	var activated: int = 0
	var completed: int = 0

	func setup(definition: GameplayAbilityDefinition) -> void:
		abilities = GameplayAbilityComponent.new()
		add_child(abilities)
		abilities.set_process(false)
		abilities.ability_activated.connect(_on_activated)
		abilities.ability_completed.connect(_on_completed)
		abilities.learn_ability(definition)

	func _on_activated(_ability: GameplayAbilityInstance) -> void:
		activated += 1

	func _on_completed(_ability: GameplayAbilityInstance) -> void:
		completed += 1

func _ready() -> void:
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"pulse"
	definition.execution_tree = CommitAction.new()
	var cooldown: CooldownFeature = CooldownFeature.new()
	cooldown.cooldown_duration = 1.0
	definition.features = [cooldown]
	var a: Caster = Caster.new()
	var b: Caster = Caster.new()
	add_child(a)
	add_child(b)
	a.setup(definition)
	b.setup(definition)
	var id: StringName = definition.ability_id
	var instance_a: GameplayAbilityInstance = a.abilities.get_ability_instance(id)
	var instance_b: GameplayAbilityInstance = b.abilities.get_ability_instance(id)

	var accepted: bool = a.abilities.try_activate_ability(id, {"cooldown_reduction": 0.5})
	var activation_only: bool = accepted and a.activated == 1 and a.completed == 0 \
		and instance_a.is_active and is_zero_approx(cooldown.get_cooldown_remaining(instance_a))
	instance_a.update(0.0)
	var completed: bool = a.completed == 1 and not instance_a.is_active \
		and is_equal_approx(cooldown.get_cooldown_remaining(instance_a), 0.5)
	var rejected: bool = not a.abilities.can_activate_ability(id) and not a.abilities.try_activate_ability(id) \
		and a.activated == 1 and a.completed == 1
	var independent: bool = b.abilities.try_activate_ability(id) \
		and is_zero_approx(cooldown.get_cooldown_remaining(instance_b))
	instance_b.update(0.0)
	instance_a.update(0.5)
	var recovered: bool = a.abilities.try_activate_ability(id) and a.activated == 2 \
		and is_equal_approx(cooldown.get_cooldown_remaining(instance_b), 1.0) and b.completed == 1
	if not (activation_only and completed and rejected and independent and recovered):
		push_error("Ability-only activation, cooldown, or instance isolation failed")
		get_tree().quit.call_deferred(1)
		return
	print("PASS: Ability-only activation and cooldown")
	get_tree().quit.call_deferred(0)
