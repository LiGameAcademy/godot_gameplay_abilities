extends Node

## 挂点工具类（单例）
## 提供统一的挂点查找功能，支持业务层覆盖查找方法
##
## 使用方式：
## 1. 默认使用内置的查找逻辑
## 2. 业务层可以通过 set_custom_finder 方法覆盖查找逻辑
## 3. 支持通过 get_attachment_point_position 直接获取挂点位置

## 自定义查找器函数类型
## [param] target: Node 目标节点
## [param] attachment_point: StringName 挂点名
## [return] Vector3 挂点位置（世界坐标），如果找不到则返回 Vector3.ZERO
var custom_finder: Callable = Callable()

## 获取挂点位置
## [param] target: Node 目标节点
## [param] attachment_point: StringName 挂点名（如 "head", "foot", "weapon" 等）
## [return] Vector3 挂点位置（世界坐标）
func get_attachment_point_position(target: Node, attachment_point: StringName) -> Vector3:
	if not is_instance_valid(target):
		return Vector3.ZERO
	
	# 如果设置了自定义查找器，优先使用
	if custom_finder.is_valid():
		var result = custom_finder.call(target, attachment_point)
		if result is Vector3:
			return result as Vector3
	
	# 使用默认查找逻辑
	return _get_attachment_point_position_default(target, attachment_point)

## 设置自定义查找器（允许业务层覆盖）
## [param] finder: Callable 自定义查找函数，接收 (target: Node, attachment_point: StringName) -> Vector3
func set_custom_finder(finder: Callable) -> void:
	custom_finder = finder

## 清除自定义查找器（恢复默认行为）
func clear_custom_finder() -> void:
	custom_finder = Callable()

## 默认的挂点查找逻辑
## [param] target: Node 目标节点
## [param] attachment_point: StringName 挂点名
## [return] Vector3 挂点位置（世界坐标）
func _get_attachment_point_position_default(target: Node, attachment_point: StringName) -> Vector3:
	# 如果目标实现了 get_attachment_point 方法，直接调用
	if target.has_method("get_attachment_point"):
		var point = target.get_attachment_point(attachment_point)
		if is_instance_valid(point) and point is Node3D:
			return (point as Node3D).global_position
	
	# 否则，尝试通过常见路径查找挂点节点
	var point_node = _find_attachment_point_node(target, attachment_point)
	if is_instance_valid(point_node) and point_node is Node3D:
		return (point_node as Node3D).global_position
	
	# 如果找不到挂点，返回目标节点的位置
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

