class_name BTInstance
extends RefCounted

var agent: Node
var tree_root: BTNode
var blackboard: BTBlackboard = BTBlackboard.new()

# 当前正在运行的节点路径（用于判断优先级）
# 简单起见，我们存储当前运行的 Leaf 节点，以及它的所有祖先装饰器
var active_nodes: Array[BTNode] = []

# 已注册的观察者列表
var _observers: Array[BTObserver] = []

func _init(p_agent: Node, p_tree_root: BTNode):
	agent = p_agent
	tree_root = p_tree_root
	blackboard.value_changed.connect(_on_blackboard_changed)

func tick(delta: float) -> int: # 或 BTNode.Status
	if not tree_root or not is_instance_valid(agent):
		return BTNode.Status.FAILURE # 保护性返回

	# 这里依然从 Root 开始 Tick (混合模式)，
	# 但由于有了事件中断，我们可以大大降低 tick 的频率，
	# 或者只 tick active_nodes 里的最后一个节点（纯事件模式，较复杂，建议先用混合模式）
	
	# 简单做法：依然每帧 Tick Root，利用 Observer 处理突发事件
	return tree_root.tick(self, delta)

# 只重置树的执行进度（软重置）
func reset_tree():
	if tree_root:
		tree_root.reset(self)

func evaluate_interruption(observer: BTObserver, new_status: int):
	# 这里是基于事件行为树最复杂的地方：判定优先级
	
	match observer.abort_type:
		BTObserver.AbortType.SELF:
			# 如果观察者自己正在运行（是 active_nodes 的一部分）
			# 且条件变成了 FAILURE，则中断自己
			if _is_active(observer) and new_status == BTNode.Status.FAILURE:
				_abort_execution(observer)
				
		BTObserver.AbortType.LOWER_PRIORITY:
			# 如果观察者当前没有运行（说明之前的条件是 Failure）
			# 现在条件变成了 SUCCESS，且当前运行的节点优先级比观察者低
			# 则中断当前节点，切回观察者所在的分支
			if not _is_active(observer) and new_status == BTNode.Status.SUCCESS:
				# 简单的优先级判定：在标准行为树中，
				# 如果 Observer 是 Selector 的左侧子节点，而当前运行的是右侧子节点，
				# 则 Observer 优先级更高。
				if _is_higher_priority(observer):
					_abort_execution(observer)

# 彻底重置（硬重置）
func clear_all():
	reset_tree()
	blackboard.clear()

## [API] 注入外部变量到黑板 (例如：感知到的敌人)
func set_var(key: String, value: Variant) -> void:
	blackboard[key] = value

func get_var(key: String, default: Variant = null) -> Variant:
	return blackboard.get_var(key, default)

func register_observer(observer: BTObserver):
	if observer not in _observers:
		_observers.append(observer)

func unregister_observer(observer: BTObserver):
	_observers.erase(observer)

func _is_active(node: BTNode) -> bool:
	# 需要在 BTNode.tick 中维护 active_nodes 列表才能实现
	# 这里假设你已经在 tick 里维护了这个列表
	return node in active_nodes

func _is_higher_priority(observer: BTNode) -> bool:
	# 这是一个简化的逻辑，实际上需要根据树的结构判断
	# 只要 Observer 不在 active_nodes 里，通常意味着
	# 它是某个 Selector 左侧失败的分支，现在它想变成功，
	# 那么它就有资格打断右侧正在运行的分支。
	return true 

func _abort_execution(source_node: BTNode):
	# 强制重置树，或者重置到特定节点
	print("ABORT triggered by: ", source_node)
	reset_tree() # 简单粗暴：重置整棵树，下一帧 tick 会自动走进新分支

func _on_blackboard_changed(key: String, value: Variant):
	# 当黑板变化时，通知所有注册的观察者
	# 注意：为了防止遍历中修改数组，最好用 duplicate
	for obs : BTObserver in _observers.duplicate():
		obs.on_blackboard_change(self, key)
