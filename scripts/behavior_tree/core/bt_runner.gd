extends Node
class_name BTRunner

const NodeStatus := BTNode.Status
enum RunnerMode {
	IDLE,       # _process
	PHYSICS,    # _physics_process
	MANUAL,     # 仅外部调用
}

@export var tree_root: BTNode
@export var run_mode: RunnerMode = RunnerMode.PHYSICS
@export var active: bool = true:
	set(v):
		active = v
		_update_process_mode()

var _instance: BTInstance

signal tree_finished(result: NodeStatus)

func _ready() -> void:
	var agent = get_parent()
	if not tree_root:
		push_warning("BTRunner: No Tree Root assigned for " + agent.name)
		active = false
		return

	_instance = BTInstance.new(agent, tree_root)
	_instance.blackboard.set_var("runner_node", self)
	
	_update_process_mode()

func _process(delta: float) -> void:
	tick(delta)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not is_instance_valid(_instance):
		return
	
	var result = _instance.tick(delta)
	if result != NodeStatus.RUNNING:
		tree_finished.emit(result)

func reset() -> void:
	if not is_instance_valid(_instance):
		return
	_instance.reset()

func get_blackboard() -> Dictionary:
	return _instance.blackboard if is_instance_valid(_instance) else {}

func set_var(key: String, value: Variant) -> void:
	if not is_instance_valid(_instance):
		return
	_instance.set_var(key, value)

func get_var(key: String, default: Variant = null) -> Variant:
	return _instance.get_var(key, default) if is_instance_valid(_instance) else default

func _update_process_mode() -> void:
	set_process(active and run_mode == RunnerMode.IDLE)
	set_physics_process(active and run_mode == RunnerMode.PHYSICS)
