extends Node

## 游戏提示管理器（单例）
## 负责执行 Cue，处理所有表现相关的脏活累活
## 核心思想：Fire and Forget（射后不理）
## 采用组合模式，将具体表现处理交给 Cue 组件

## 飘字场景模板（用于初始化飘字 Cue 的对象池）
var _floating_text_template: PackedScene = null

func _ready() -> void:
	# 初始化飘字模板
	_init_floating_text_template()

## 初始化飘字模板
func _init_floating_text_template() -> void:
	_floating_text_template = load("res://prefabs/floating_text.tscn")
	if not is_instance_valid(_floating_text_template):
		push_warning("GameplayCueManager: Floating text scene not found")

## 执行 Cue（核心接口）
## [param] cue: GameplayCue Cue 资源
## [param] target: Node 目标节点（用于计算挂点位置）
## [param] context: Dictionary 上下文信息（可选，如伤害值、治疗值等）
func execute_cue(cue: GameplayCue, target: Node, context: Dictionary = {}) -> void:
	if not is_instance_valid(cue):
		return
	
	# 遍历所有 Cue 组件并执行
	for cue_component in cue.cues:
		if not is_instance_valid(cue_component):
			continue
		
		# 计算挂点位置
		var location = _get_attachment_point_position(target, cue_component.attachment_point)
		
		# 初始化飘字 Cue 的对象池（如果需要）
		if cue_component.has_method("initialize_pool"):
			if cue_component.get("_text_template") == null and is_instance_valid(_floating_text_template):
				cue_component.initialize_pool(_floating_text_template, 10)
		
		# 执行 Cue 组件
		cue_component.execute(target, location, context)

## 获取挂点位置
## [param] target: Node 目标节点
## [param] attachment_point: StringName 挂点名（如 "head", "foot", "weapon" 等）
## [return] Vector3 挂点位置（世界坐标）
func _get_attachment_point_position(target: Node, attachment_point: StringName) -> Vector3:
	if not is_instance_valid(target):
		return Vector3.ZERO
	
	# 如果目标实现了 get_attachment_point 方法，直接调用
	if target.has_method("get_attachment_point"):
		var point = target.get_attachment_point(attachment_point)
		if is_instance_valid(point) and point is Node3D:
			return (point as Node3D).global_position
	
	# 如果找不到挂点，返回目标节点的位置
	push_warning("GameplayCueManager: Target %s has no attachment point %s" % [target.name, attachment_point])
	return _get_node_3d_position(target)

## 查找挂点节点（通过常见路径）
## [param] target: Node 目标节点
## [param] attachment_point: StringName 挂点名
## [return] Node 挂点节点，如果找不到则返回 null
func _find_attachment_point_node(target: Node, attachment_point: StringName) -> Node:
	if not is_instance_valid(target):
		return null
	
	# 常见挂点路径映射
	var common_paths = {
		&"root": "",
		&"head": "Visuals/Head",
		&"foot": "Visuals/Foot",
		&"body": "Visuals/Body",
		&"weapon": "Visuals/Weapon",
		&"muzzle": "Visuals/Weapon/Muzzle",
		&"chest": "Visuals/Chest",
		&"back": "Visuals/Back",
	}
	
	# 查找路径
	var path_str = common_paths.get(attachment_point, "")
	if path_str == "":
		# 如果没有预定义路径，尝试直接查找同名节点
		path_str = str(attachment_point)
	
	# 尝试从目标节点查找
	var point_node = target.get_node_or_null(path_str)
	if is_instance_valid(point_node):
		return point_node
	
	# 尝试从 Visuals 子节点查找
	var visuals = target.get_node_or_null("Visuals")
	if is_instance_valid(visuals):
		point_node = visuals.get_node_or_null(path_str.trim_prefix("Visuals/"))
		if is_instance_valid(point_node):
			return point_node
	
	return null

## 获取节点的 3D 位置
## [param] node: Node 节点
## [return] Vector3 3D 位置
func _get_node_3d_position(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	
	# 尝试从子节点获取 Node3D
	var visuals = node.get_node_or_null("Visuals")
	if is_instance_valid(visuals) and visuals is Node3D:
		return (visuals as Node3D).global_position
	
	# 尝试查找任何 Node3D 子节点
	for child in node.get_children():
		if child is Node3D:
			return (child as Node3D).global_position
	
	return Vector3.ZERO
