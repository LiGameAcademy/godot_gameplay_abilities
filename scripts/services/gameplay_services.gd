extends RefCounted
class_name GameplayServices
## Optional services supplied by the host for a status component and its effects.

const EventBus = preload("../singletons/ability_event_bus.gd")
const Tags = preload("../singletons/gameplay_tag_manager.gd")
const Cues = preload("../singletons/gameplay_cue_manager.gd")
const CONTEXT_KEY: StringName = &"_gas_services"

var events: EventBus
var tags: Tags
var cues: Cues

## Resolves the existing full-plugin Autoloads, if the host registered them.
static func from_autoloads() -> GameplayServices:
	var services: GameplayServices = GameplayServices.new()
	services.events = EventBus.get_default() as EventBus
	services.tags = _autoload(&"TagManager") as Tags
	services.cues = _autoload(&"GameplayCueManager") as Cues
	return services

static func events_for_effect(context: Dictionary) -> EventBus:
	var services: GameplayServices = context.get(CONTEXT_KEY) as GameplayServices
	return services.events if services != null else EventBus.get_default() as EventBus

static func tags_for_effect(context: Dictionary) -> Tags:
	var services: GameplayServices = context.get(CONTEXT_KEY) as GameplayServices
	return services.tags if services != null else _autoload(&"TagManager") as Tags

static func cues_for_effect(context: Dictionary) -> Cues:
	var services: GameplayServices = context.get(CONTEXT_KEY) as GameplayServices
	return services.cues if services != null else _autoload(&"GameplayCueManager") as Cues

## The compatibility boundary for projects using the existing named Autoloads.
static func _autoload(service_name: StringName) -> Node:
	if not ProjectSettings.has_setting("autoload/" + String(service_name)):
		return null
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(service_name)))
