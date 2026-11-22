extends Node

const ID: StringName = &"targeted_mark"

var _abilities: GameplayAbilityComponent
var _payer: GameplayVitalAttributeComponent
var _target: GameplayStatusComponent
var _ability: GameplayAbilityInstance
var _cooldown: CooldownFeature
var _in_range: bool = true
var _writes: Array[float] = []
var _applied: int = 0
var _removed: int = 0
var _completed: int = 0
var _failed: bool = false

func _ready() -> void:
	_setup()
	_run_cases()
	if not _failed:
		print("PASS: GAS authoritative targeted status cast")
	get_tree().quit.call_deferred(int(_failed))

func _setup() -> void:
	_abilities = GameplayAbilityComponent.new()
	_payer = GameplayVitalAttributeComponent.new()
	_target = GameplayStatusComponent.new()
	var victim: Node = Node.new()
	add_child(_abilities)
	add_child(_payer)
	add_child(victim)
	victim.add_child(_target)
	var maximum: GameplayAttribute = GameplayAttribute.new()
	maximum.attribute_id = &"max_mana"
	var stats: GameplayAttributeSet = GameplayAttributeSet.new()
	stats.attributes = {maximum: 10.0}
	var mana: GameplayVital = GameplayVital.new()
	mana.vital_id = &"mana"
	mana.max_value_attribute = &"max_mana"
	_payer.initialize([stats], [mana])

	var definition: TargetedStatusAbilityDefinition = TargetedStatusAbilityDefinition.new()
	definition.ability_id = ID
	definition.status = GameplayStatusData.new()
	definition.status.status_id = ID
	definition.status.duration = 2.0
	_abilities.learn_ability(definition)
	_ability = _abilities.get_ability_instance(ID)
	_cooldown = _ability.get_feature("CooldownFeature") as CooldownFeature

	_payer.vital_value_changed.connect(_on_payment)
	_target.status_applied.connect(func(_id: StringName, _status: GameplayStatusInstance) -> void: _applied += 1)
	_target.status_removed.connect(func(_id: StringName) -> void: _removed += 1)
	_abilities.ability_completed.connect(func(_instance: GameplayAbilityInstance) -> void: _completed += 1)

func _run_cases() -> void:
	var cast: TargetedStatusAbilityDefinition.Cast = _start()
	_ability.update(0.5)
	_check(_ability.is_active and _writes.is_empty() and _applied == 0, "windup does not settle")
	var duplicate: TargetedStatusAbilityDefinition.Cast = _new_cast()
	_check(not _activate(duplicate), "active cast cannot be replaced")
	_ability.update(0.5)
	_check(cast.result == TargetedStatusAbilityDefinition.Result.APPLIED and _writes == [6.0]
		and _applied == 1 and _target.has_status(ID) and _cooldown.get_cooldown_remaining(_ability) == 3.0
		and not _ability.is_active and _completed == 1, "one payment, cooldown, and application")
	_check(not _activate(_new_cast()), "cooldown rejects a new cast")
	_target._process(2.0)
	_ability.update(3.0)
	_check(_removed == 1 and not _target.has_status(ID), "authoritative status expiry")

	cast = _start()
	_ability.update(0.5)
	_check(_payer.try_spend(&"mana", 3.0), "fixture spends during windup")
	_ability.update(0.5)
	_check(cast.result == TargetedStatusAbilityDefinition.Result.PAYMENT_FAILED and _writes == [6.0, 3.0]
		and _applied == 1 and _cooldown.get_cooldown_remaining(_ability) == 0.0
		and _completed == 2 and not _ability.is_active, "payment failure has no partial settlement")
	_payer.modify_vital(&"mana", 7.0)
	_writes.clear()

	cast = _start()
	_in_range = false
	_ability.update(1.0)
	_check(cast.result == TargetedStatusAbilityDefinition.Result.TARGET_INVALID and _writes.is_empty()
		and _applied == 1 and _cooldown.get_cooldown_remaining(_ability) == 0.0
		and _completed == 3 and not _ability.is_active, "range rechecked before payment")
	_in_range = true

	cast = _start()
	_abilities.cancel_ability(ID)
	_ability.update(2.0)
	_check(cast.result == TargetedStatusAbilityDefinition.Result.CANCELLED and _writes.is_empty()
		and _applied == 1 and _cooldown.get_cooldown_remaining(_ability) == 0.0
		and _completed == 4 and not _ability.is_active, "cancellation cleans the windup")

	cast = _start()
	_payer.vital_value_changed.connect(_cancel_during_payment, CONNECT_ONE_SHOT)
	_ability.update(1.0)
	_check(cast.result == TargetedStatusAbilityDefinition.Result.STATUS_NOT_APPLIED and _writes == [6.0]
		and _applied == 1 and _cooldown.get_cooldown_remaining(_ability) == 3.0
		and _completed == 5 and not _ability.is_active, "successful payment survives reentrant cancellation")
	_check(not _ability.get_blackboard_var("context", {}).has(TargetedStatusAbilityDefinition.CAST_KEY),
		"completion releases the cast context")

func _new_cast() -> TargetedStatusAbilityDefinition.Cast:
	return TargetedStatusAbilityDefinition.Cast.new(_payer, _target, _is_target_in_range)

func _start() -> TargetedStatusAbilityDefinition.Cast:
	var cast: TargetedStatusAbilityDefinition.Cast = _new_cast()
	_check(_activate(cast), "accepted cast")
	return cast

func _activate(cast: TargetedStatusAbilityDefinition.Cast) -> bool:
	return _abilities.try_activate_ability(ID, {TargetedStatusAbilityDefinition.CAST_KEY: cast})

func _is_target_in_range(_component: GameplayStatusComponent) -> bool:
	return _in_range

func _on_payment(_id: StringName, current: float, _maximum: float, _percent: float, _regen: bool) -> void:
	_writes.append(current)

func _cancel_during_payment(_id: StringName, _current: float, _maximum: float,
		_percent: float, _regen: bool) -> void:
	_abilities.cancel_ability(ID)
	_target.queue_free()

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error(label)
