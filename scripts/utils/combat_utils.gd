extends Node

## 战斗工具类（单例）
## 提供通用的工具函数，解决物理检测与逻辑检测的兼容性问题

## 从碰撞体获取实体根节点
## 解决物理检测返回collider，但需要找到拥有组件的实体根节点的问题
## [param] collider: Node 碰撞体节点（可能是CollisionShape3D、Area3D等）
## [return] Node 实体根节点（拥有战斗组件的节点），如果找不到则返回null
func get_entity_from_collider(collider: Node) -> Node:
	if not is_instance_valid(collider):
		return null
	
	# 策略1：检查collider本身是否有战斗组件（可能是实体根节点）
	if _has_combat_component(collider):
		return collider
	
	# 策略2：向上查找，直到找到有战斗组件的节点
	var current = collider
	var max_depth = 10  # 防止无限循环
	var depth = 0
	
	while current and depth < max_depth:
		# 检查当前节点
		if _has_combat_component(current):
			return current
		
		# 检查父节点
		current = current.get_parent()
		depth += 1
	
	# 策略3：通过组（Group）查找
	# 如果碰撞体在某个组中，尝试查找同组的实体
	if collider.is_in_group("combat_entity"):
		return collider
	
	# 策略4：通过元数据（Metadata）查找
	if collider.has_meta("combat_entity"):
		var entity = collider.get_meta("combat_entity")
		if is_instance_valid(entity):
			return entity
	
	# 策略5：查找最近的拥有HealthComponent的节点
	var health_comp = GameplayAbilitySystem.get_component_by_interface(collider, "HealthComponent")
	if is_instance_valid(health_comp):
		return health_comp.get_parent()
	
	# 如果都找不到，返回collider本身（向后兼容）
	return collider

## 从节点获取实体根节点
## [param] node: Node 任意节点
## [return] Node 实体根节点
func get_entity_from_node(node: Node) -> Node:
	if not is_instance_valid(node):
		return null
	
	# 如果已经是实体根节点，直接返回
	if _has_combat_component(node):
		return node
	
	# 向上查找
	var current = node
	var max_depth = 10
	var depth = 0
	
	while current and depth < max_depth:
		if _has_combat_component(current):
			return current
		current = current.get_parent()
		depth += 1
	
	# 如果找不到，返回原节点（向后兼容）
	return node

## 检查节点是否有战斗组件（使用鸭子类型）
func _has_combat_component(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	
	# 检查是否有任何战斗组件
	var components = [
		"GameplayAttributeComponent",
		"GameplayStatusComponent",
		"GameplayAbilityComponent",
		"GameplayVitalAbilityComponent"
	]
	
	for comp_name in components:
		if GameplayAbilitySystem.has_component(node, comp_name):
			return true
	
	return false

## 获取节点的3D位置
## [param] node: Node 节点
## [return] Vector3 3D位置，如果节点不是Node3D则返回Vector3.ZERO
func get_node_3d_position(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	
	# 尝试从子节点获取Node3D
	for child in node.get_children():
		if child is Node3D:
			return (child as Node3D).global_position
	
	return Vector3.ZERO

## 检查两个节点之间是否有视线（Line of Sight）
## [param] from_node: Node 起始节点
## [param] to_node: Node 目标节点
## [param] layer_mask: int 碰撞遮罩
## [return] bool 是否有视线
func has_line_of_sight(from_node: Node, to_node: Node, layer_mask: int = 1) -> bool:
	var from_pos = get_node_3d_position(from_node)
	var to_pos = get_node_3d_position(to_node)
	
	if from_pos == Vector3.ZERO or to_pos == Vector3.ZERO:
		return false
	
	# 获取世界空间状态
	var from_3d = from_node as Node3D
	if not from_3d:
		# 尝试从子节点获取
		for child in from_node.get_children():
			if child is Node3D:
				from_3d = child
				break
	
	if not from_3d:
		return false
	
	var space_state = from_3d.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = layer_mask
	query.exclude = [from_node, to_node]
	
	var result = space_state.intersect_ray(query)
	return not result  # 如果没有阻挡，返回true
