extends Node
## Verifies periodic damage and attribution in two battles without Autoloads.

class Combatant extends Node:
	var vitals: GameplayVitalAttributeComponent
	var statuses: GameplayStatusComponent
	var services: GameplayServices
	var values: Array[float] = []
	var killers: Array[Node] = []
	var received: int = 0
	var applied: int = 0

	func setup(maximum: float) -> void:
		services = GameplayServices.new()
		services.events = GameplayServices.EventBus.new()
		services.tags = GameplayServices.Tags.new()
		add_child(services.events)
		add_child(services.tags)
		var immunity: GameplayTag = GameplayTag.new()
		immunity.id = &"state.invulnerable"
		services.tags.register_tag(immunity)
		services.events.subscribe_to_event(&"damage_received", _count_received)
		services.events.subscribe_to_event(&"damage_applied", _count_applied)

		var max_health: GameplayAttribute = GameplayAttribute.new()
		max_health.attribute_id = &"max_health"
		var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
		attributes.attributes[max_health] = maximum
		vitals = GameplayVitalAttributeComponent.new()
		vitals.name = &"GameplayVitalAttributeComponent"
		add_child(vitals)
		vitals.initialize([attributes], [HealthVital.new()])
		vitals.vital_value_changed.connect(_record_health)
		vitals.health_depleted.connect(_record_killer)
		statuses = GameplayStatusComponent.new()
		statuses.configure_services(services)
		add_child(statuses)
		statuses.set_process(false)

	func _record_health(id: StringName, current: float, _maximum: float, _fraction: float, _regen: bool) -> void:
		if id == &"health":
			values.append(current)

	func _record_killer(_id: StringName, instigator: Node) -> void:
		killers.append(instigator)

	func _count_received(_event: StringName, _context: Dictionary) -> void:
		received += 1

	func _count_applied(_event: StringName, _context: Dictionary) -> void:
		applied += 1

func _ready() -> void:
	var attacker: Node = Node.new()
	add_child(attacker)
	var a: Combatant = Combatant.new()
	var b: Combatant = Combatant.new()
	add_child(a)
	add_child(b)
	a.setup(8.0)
	b.setup(20.0)
	var bleeding: GameplayStatusData = create_bleeding()
	a.statuses.apply_status(bleeding, attacker)
	b.statuses.apply_status(bleeding, attacker)

	a.statuses._process(0.25)
	var no_early_tick: bool = a.values.is_empty()
	a.statuses._process(0.25)
	var isolated: bool = a.values == [5.0] and a.received == 1 and a.applied == 1 \
			and b.values.is_empty() and b.received == 0 and b.applied == 0
	b.services.tags.add_tag(b, &"state.invulnerable")
	b.statuses._process(0.5)
	var immune: bool = b.values.is_empty() and b.received == 0 and b.applied == 0
	b.services.tags.remove_tag(b, &"state.invulnerable")
	b.statuses._process(0.5)
	b.statuses._process(0.5)
	b.statuses._process(0.5)
	b.statuses._process(0.5)

	for step: int in range(4):
		a.statuses._process(0.5)
	var lethal: bool = a.values == [5.0, 2.0, 0.0] and a.received == 3 and a.applied == 3 \
			and a.killers == [attacker] and a.is_in_group(HealthVital.DEATH_GROUP_NAME)
	var stopped: bool = not a.statuses.has_status(bleeding.status_id) and not b.statuses.has_status(bleeding.status_id) \
			and b.values == [17.0, 14.0] and b.killers.is_empty() and b.received == 2 and b.applied == 2
	if not no_early_tick or not isolated or not immune or not lethal or not stopped:
		push_error("Periodic damage mismatch: A %s (%d/%d), B %s (%d/%d)" % [
			a.values, a.received, a.applied, b.values, b.received, b.applied
		])
		get_tree().quit.call_deferred(1)
		return
	print("PASS: Status + Vital periodic damage")
	get_tree().quit.call_deferred(0)

static func create_bleeding() -> GameplayStatusData:
	var damage: GE_ApplyDamage = GE_ApplyDamage.new()
	damage.fixed_base_damage = 3.0
	var periodic: FeaturePeriodicEffects = FeaturePeriodicEffects.new()
	periodic.period = 0.5
	periodic.periodic_effects = [damage]
	var bleeding: GameplayStatusData = GameplayStatusData.new()
	bleeding.status_id = &"bleeding"
	bleeding.duration = 2.0
	bleeding.features = [periodic]
	return bleeding
