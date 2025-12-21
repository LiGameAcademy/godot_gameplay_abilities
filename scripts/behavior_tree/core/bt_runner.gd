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

@export var debug_blackboard: bool = false

var _instance: BTInstance

signal tree_finished(result: NodeStatus)

func _ready() -> void:
	var agent = get_parent()
	# 简单的防呆保护
	if not tree_root:
		push_warning("BTRunner: No Tree Root assigned for " + agent.name)
		active = false
		return
		
	_instance = BTInstance.new(agent, tree_root)
	_instance.blackboard["runner_node"] = self
	
	_update_process_mode()

func _update_process_mode():
	set_process(active and run_mode == RunnerMode.IDLE)
	set_physics_process(active and run_mode == RunnerMode.PHYSICS)

func _process(delta: float) -> void:
	# [修正] 调用 self.tick 而不是 _instance.tick，确保逻辑统一
	tick(delta)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not _instance: return
	
	# [修正] 接收返回值
	var result = _instance.tick(delta)
	
	if debug_blackboard:
		_print_debug()
		
	# [策略补全] 自动重置逻辑
	if result != NodeStatus.RUNNING:
		if run_mode == RunnerMode.MANUAL:
			# 手动模式下，可以发出信号供外部处理
			tree_finished.emit(result)
			pass
		else:
			# AI模式下：如果不重置，Sequence 会保留在"已完成"状态
			# 通常我们需要树在下一帧重新开始评估
			# 注意：这里的 reset 不会清空黑板的持久数据，只会重置节点运行状态
			# 如果你想保留黑板数据，需要修改 BTInstance.reset 的逻辑，只调用 tree_root.reset
			# 这里我们假设 behavior tree 是无状态循环的，重置是为了下一次 tick 从头开始
			# 但为了防止一帧内重置导致逻辑抖动，通常不在这里 reset，
			# 而是依赖 Composite 节点自身的逻辑 (Sequence 完成后会自动清理自己的黑板状态)
			pass

func reset() -> void:
	if _instance: _instance.reset()

func get_blackboard() -> Dictionary:
	return _instance.blackboard if _instance else {}

func set_var(key: String, value: Variant) -> void:
	if _instance: _instance.set_var(key, value)

func get_var(key: String, default: Variant = null) -> Variant:
	return _instance.get_var(key, default) if _instance else default

func _print_debug():
	var debug_dict = {}
	for k in _instance.blackboard:
		if k is String:
			debug_dict[k] = _instance.blackboard[k]
	print("BT Debug [", get_parent().name, "]: ", debug_dict)

# [彩蛋] 让黑板数据在 Godot 编辑器 Inspector 中可见
func _get_property_list() -> Array[Dictionary]:
	var props = []
	props.append({
		"name": "Runtime/Blackboard",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	})
	return props

func _get(property: StringName):
	if property == "Runtime/Blackboard" and _instance:
		# 过滤掉 Resource key，只显示 String key 方便查看
		var visible = {}
		for k in _instance.blackboard:
			if k is String: visible[k] = _instance.blackboard[k]
		return visible
	return null
