extends Node
## Verifies Status lifecycle and shared services without battle or ability modules.

class Actor extends Node3D:
	func get_attachment_point(_point: StringName) -> Node3D:
		return self

class TickEffect extends GameplayEffect:
	func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
		target.set_meta(&"ticks", int(target.get_meta(&"ticks", 0)) + 1)

class StatusCue extends GameplayCueBase:
	func _execute(target: Node, _location: Vector3, _context: Dictionary) -> void:
		target.set_meta(&"cue_active", true)

	func _stop(target: Node) -> void:
		target.set_meta(&"cue_active", false)

const STATUS_ID: StringName = &"module_profile_status"
const TAG_ID: StringName = &"status.module_profile"

func _ready() -> void:
	if not _test_basic_status() or not _test_local_services() or not _test_scoped_events():
		get_tree().quit.call_deferred(1)
		return
	print("PASS: Status host")
	get_tree().quit.call_deferred(0)

func _test_basic_status() -> bool:
	var actor: Node = Node.new()
	add_child(actor)
	var component: GameplayStatusComponent = GameplayStatusComponent.new()
	actor.add_child(component)
	component.set_process(false)
	var definition: GameplayStatusData = GameplayStatusData.new()
	definition.status_id = STATUS_ID
	definition.duration = 0.5
	definition.max_stacks = 2
	definition.stacking_policy = StackingRefreshAndStack.new()
	var status: GameplayStatusInstance = component.apply_status(definition, actor)
	if status == null:
		actor.free()
		return _expect(false, "Basic Status did not apply")
	component._process(0.25)
	component.apply_status(definition, actor)
	var refreshed: bool = status.stacks == 2 and status.remaining_duration == 0.5
	component._process(0.25)
	var still_active: bool = component.has_status(STATUS_ID)
	component._process(0.25)
	var expired: bool = not component.has_status(STATUS_ID)
	actor.free()
	return _expect(refreshed and still_active and expired, "Basic Status did not stack, refresh and expire")

func _test_local_services() -> bool:
	var actor: Actor = Actor.new()
	add_child(actor)
	var services: GameplayServices = GameplayServices.new()
	services.tags = GameplayServices.Tags.new()
	services.cues = GameplayServices.Cues.new()
	actor.add_child(services.tags)
	actor.add_child(services.cues)
	var component: GameplayStatusComponent = GameplayStatusComponent.new()
	component.configure_services(services)
	actor.add_child(component)
	component.set_process(false)
	var tag: GameplayTag = GameplayTag.new()
	tag.id = TAG_ID
	services.tags.register_tag(tag)
	var definition: GameplayStatusData = GameplayStatusData.new()
	definition.status_id = STATUS_ID
	definition.duration = 1.0
	definition.max_stacks = 2
	definition.stacking_policy = StackingRefreshAndStack.new()
	definition.tags = [TAG_ID]
	var periodic: FeaturePeriodicEffects = FeaturePeriodicEffects.new()
	periodic.period = 0.25
	var tick: TickEffect = TickEffect.new()
	tick.target_required_tags = [TAG_ID]
	periodic.periodic_effects = [tick]
	definition.features = [periodic]
	definition.cue = GameplayCue.new()
	definition.cue.cues = [StatusCue.new()]

	var applied: Array[StringName] = []
	var removed: Array[StringName] = []
	component.status_applied.connect(func(id: StringName, _status: GameplayStatusInstance) -> void: applied.append(id))
	component.status_removed.connect(func(id: StringName) -> void: removed.append(id))
	var instance: GameplayStatusInstance = component.apply_status(definition, actor)
	var started: bool = instance != null and instance.stacks == 1 and component.has_status(STATUS_ID) \
			and services.tags.has_tag(actor, TAG_ID) and actor.get_meta(&"cue_active", false)
	component._process(0.25)
	component.apply_status(definition, actor)
	component.apply_status(definition, actor)
	var stacked: bool = instance != null and component.get_status(STATUS_ID) == instance \
			and instance.stacks == 2 and instance.remaining_duration == 1.0 \
			and actor.get_meta(&"ticks", 0) == 1
	component._process(0.25)
	component._process(0.5)
	var still_active: bool = component.has_status(STATUS_ID)
	var ticks_before_expiry: int = actor.get_meta(&"ticks", 0)
	component._process(0.25)
	component._process(0.25)
	var expired: bool = not component.has_status(STATUS_ID) and not services.tags.has_tag(actor, TAG_ID) \
			and not actor.get_meta(&"cue_active", true) and actor.get_meta(&"ticks", 0) == ticks_before_expiry
	actor.free()
	return _expect(started and stacked and still_active and expired \
			and ticks_before_expiry == 3 and applied == [STATUS_ID] and removed == [STATUS_ID],
			"Local Status services did not preserve effects, tags or Cue transitions")

func _test_scoped_events() -> bool:
	var event_id: StringName = &"module_profile_trigger"
	var definition: GameplayStatusData = GameplayStatusData.new()
	definition.status_id = STATUS_ID
	var listener: FeatureEventListener = FeatureEventListener.new()
	listener.trigger_on_events = [event_id]
	listener.event_triggered_effects = [TickEffect.new()]
	definition.features = [listener]
	var battle_a: Node = Node.new()
	var battle_b: Node = Node.new()
	add_child(battle_a)
	add_child(battle_b)
	var component_a: GameplayStatusComponent = _bind_battle(battle_a, definition)
	var component_b: GameplayStatusComponent = _bind_battle(battle_b, definition)
	var events_a: GameplayServices.EventBus = component_a.get_services().events
	var order: Array[String] = []
	var default_events: GameplayServices.EventBus = GameplayServices.from_autoloads().events
	if is_instance_valid(default_events):
		default_events.trigger_game_event(event_id)
	var excluded_default: bool = battle_a.get_meta(&"ticks", 0) == 0 and battle_b.get_meta(&"ticks", 0) == 0
	events_a.game_event_occurred.connect(func(_event: StringName, _context: Dictionary) -> void: order.append("signal"))
	events_a.subscribe_to_event(event_id, func(_event: StringName, _context: Dictionary) -> void: order.append("subscriber"))
	events_a.trigger_game_event(event_id)
	var isolated: bool = battle_a.get_meta(&"ticks", 0) == 1 and battle_b.get_meta(&"ticks", 0) == 0
	component_b.get_services().events.trigger_game_event(event_id)
	var both: bool = battle_a.get_meta(&"ticks", 0) == 1 and battle_b.get_meta(&"ticks", 0) == 1
	battle_a.free()
	component_b.get_services().events.trigger_game_event(event_id)
	var survived: bool = battle_b.get_meta(&"ticks", 0) == 2
	battle_b.free()
	return _expect(excluded_default and isolated and both and survived and order == ["signal", "subscriber"],
			"Battle events crossed scopes or changed synchronous dispatch order")

func _bind_battle(battle: Node, definition: GameplayStatusData) -> GameplayStatusComponent:
	var services: GameplayServices = GameplayServices.new()
	services.events = GameplayServices.EventBus.new()
	battle.add_child(services.events)
	var component: GameplayStatusComponent = GameplayStatusComponent.new()
	component.configure_services(services)
	battle.add_child(component)
	component.apply_status(definition, battle)
	return component

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition
