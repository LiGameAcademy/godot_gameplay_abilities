class_name BTInstance
extends RefCounted

var agent: Node
var tree_root: BTNode
var blackboard: BTBlackboard

# 当前正在运行的节点路径（用于判断优先级）
# 简单起见，我们存储当前运行的 Leaf 节点，以及它的所有祖先装饰器
var active_nodes: Array[BTNode] = []

# 已注册的观察者列表
# 注意：可以是任何实现了 on_blackboard_change 方法的 BTNode
# 包括 BTObserver（装饰器）和 BTWaitSignal（动作节点）等
var _observers: Array[BTNode] = []

# 节点状态记录（用于判断节点是否在运行，不干扰 _node_memory 中的存储数据）
# Key 是 BTNode 引用，Value 是状态值（int）
var _node_status: Dictionary = {}

# 节点执行记录（用于调试面板）
# 格式：Array[Dictionary] {node: BTNode, status: int, timestamp: float, frame: int}
var execution_history: Array[Dictionary] = []
var _max_history_size: int = 100  # 最大记录数量
var _current_frame: int = 0

func _init(p_agent: Node, p_tree_root: BTNode, p_blackboard: BTBlackboard = null) -> void:
	agent = p_agent
	tree_root = p_tree_root
	blackboard = p_blackboard if is_instance_valid(p_blackboard) else BTBlackboard.new()
	blackboard.value_changed.connect(_on_blackboard_changed)

func tick(delta: float) -> int: # 或 BTNode.Status
	if not tree_root or not is_instance_valid(agent):
		return BTNode.Status.FAILURE # 保护性返回

	_current_frame += 1
	
	# 这里依然从 Root 开始 Tick (混合模式)，
	# 但由于有了事件中断，我们可以大大降低 tick 的频率，
	# 或者只 tick active_nodes 里的最后一个节点（纯事件模式，较复杂，建议先用混合模式）
	
	# 简单做法：依然每帧 Tick Root，利用 Observer 处理突发事件
	var result = tree_root.tick(self, delta)
	
	# 记录根节点执行结果（可选，如果不想记录根节点可以注释掉）
	# _record_execution(tree_root, result)
	
	return result

## 记录节点执行（由 BTNode.tick 调用）
func record_node_execution(node: BTNode, status: int) -> void:
	_record_execution(node, status)

## 获取执行历史（用于调试面板）
func get_execution_history() -> Array[Dictionary]:
	return execution_history.duplicate()

## 清空执行历史
func clear_execution_history() -> void:
	execution_history.clear()
	_current_frame = 0

# 只重置树的执行进度（软重置）
func reset_tree():
	if tree_root:
		tree_root.reset(self)

func evaluate_interruption(observer: BTNode, new_status: int):
	# 这里是基于事件行为树最复杂的地方：判定优先级
	# 注意：只有 BTObserver 类型的观察者才支持中断逻辑
	# BTWaitSignal 等节点只监听变化，不触发中断
	if not observer is BTObserver:
		return
	
	var bt_observer = observer as BTObserver
	
	match bt_observer.abort_type:
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

func set_node_status(node: BTNode, status: int) -> void:
	_node_status[node] = status

func get_node_status(node: BTNode, default: int = -1) -> int:
	return _node_status.get(node, default)

func has_node_status(node: BTNode) -> bool:
	return _node_status.has(node)

func erase_node_status(node: BTNode) -> void:
	_node_status.erase(node)

func clear_node_status() -> void:
	_node_status.clear()

## 注册观察者
func register_observer(observer: BTNode) -> void:
	if not observer.has_method("on_blackboard_change"):
		push_warning("Observer does not have on_blackboard_change method")
		return
	if observer not in _observers:
		_observers.append(observer)

## 注销观察者
func unregister_observer(observer: BTNode) -> void:
	if not observer.has_method("on_blackboard_change"):
		push_warning("Observer does not have on_blackboard_change method")
		return
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

## 中断执行
func _abort_execution(source_node: BTNode):
	# 强制重置树，或者重置到特定节点
	print("ABORT triggered by: ", source_node)
	reset_tree() # 简单粗暴：重置整棵树，下一帧 tick 会自动走进新分支

## 内部方法：记录执行历史
func _record_execution(node: BTNode, status: int) -> void:
	if not is_instance_valid(node):
		return
	
	var timestamp = Time.get_ticks_msec() / 1000.0  # 转换为秒
	
	# 检查是否与上一条记录相同（避免重复记录）
	if execution_history.size() > 0:
		var last_record = execution_history[-1]
		if last_record.get("node") == node and last_record.get("status") == status:
			# 相同节点相同状态，只更新时间戳
			last_record["timestamp"] = timestamp
			last_record["frame"] = _current_frame
			return
	
	# 添加新记录
	execution_history.append({
		"node": node,
		"status": status,
		"timestamp": timestamp,
		"frame": _current_frame
	})
	
	# 限制历史记录大小
	if execution_history.size() > _max_history_size:
		execution_history.pop_front()

## 黑板变化时通知观察者
func _on_blackboard_changed(key: String, value: Variant):
	# 当黑板变化时，通知所有注册的观察者
	# 注意：为了防止遍历中修改数组，最好用 duplicate
	for obs : BTObserver in _observers.duplicate():
		obs.on_blackboard_change(self, key)
