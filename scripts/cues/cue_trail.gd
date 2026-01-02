extends GameplayCueBase
class_name CueTrail

@export_group("Trail Settings")
## 残影生成间隔（秒）
@export var emit_interval: float = 0.05
## 残影存活时间（秒）
@export var duration: float = 0.4
## 残影材质（Shader 材质，用于半透明、消散效果）
@export var ghost_material: ShaderMaterial = null
## 是否自动递归查找所有 MeshInstance3D
@export var auto_find_all_meshes: bool = true
## 目标网格路径数组（仅在 auto_find_all_meshes = false 时使用）
@export var target_mesh_paths: Array[NodePath] = []

@export_group("Visual Settings")
## 残影颜色（如果材质支持）
@export var ghost_color: Color = Color(0.0, 0.8, 1.0, 0.8)
## 残影缩放（相对于原模型）
@export var ghost_scale: float = 1.0

# 运行时数据
## Key: target RID (String), Value: Dictionary {
##   timer: float,
##   target: Node3D,
##   meshes: Array[MeshInstance3D],  ## 多个 mesh 实例
##   is_active: bool
## }
var _active_trails: Dictionary = {}

## 更新残影生成（由 GameplayCueManager 在 _process 中调用）
func update(delta: float) -> void:
	var to_remove: Array[String] = []
	for target_rid in _active_trails.keys():
		var trail_data = _active_trails[target_rid]

		# 检查目标是否仍然有效
		var target = trail_data.get("target") as Node3D
		if not is_instance_valid(target):
			to_remove.append(target_rid)
			continue
		
		# 检查是否激活
		if not trail_data.get("is_active", false):
			to_remove.append(target_rid)
			continue

		# 更新计时器
		var timer = trail_data.get("timer", 0.0) + delta
		trail_data["timer"] = timer

		# 如果达到生成间隔，为所有 mesh 生成残影
		if timer >= emit_interval:
			trail_data["timer"] -= emit_interval
			var meshes = trail_data.get("meshes", []) as Array[MeshInstance3D]
			for mesh in meshes:
				if is_instance_valid(mesh):
					_spawn_ghost(target, mesh)

	# 清理无效的残影
	for target_rid in to_remove:
		_active_trails.erase(target_rid)

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	# 1. 验证目标
	if not is_instance_valid(target) or not target is Node3D:
		return
	
	var target_3d = target as Node3D
	var target_rid = str(target_3d.get_rid())

	# 2. 如果已有正在运行的残影，先停止它
	if _active_trails.has(target_rid):
		_stop_trail_internal(target_rid)

	# 3. 收集所有目标网格（支持多个 mesh）
	var mesh_instances: Array[MeshInstance3D] = []
	if auto_find_all_meshes:
		# 自动递归查找所有 MeshInstance3D
		mesh_instances = _find_all_meshes_recursive(target_3d)
	else:
		# 使用指定路径查找
		var paths_to_check = target_mesh_paths.duplicate()
		# 从指定路径获取
		if not paths_to_check.is_empty():
			for path in paths_to_check:
				if path == NodePath(""):
					continue
				var mesh_node = target_3d.get_node_or_null(path)
				if is_instance_valid(mesh_node) and mesh_node is MeshInstance3D:
					mesh_instances.append(mesh_node as MeshInstance3D)
		# 如果没有找到任何 mesh，自动查找第一个
		if mesh_instances.is_empty():
			var auto_mesh = _find_target_mesh(target_3d)
			if is_instance_valid(auto_mesh):
				mesh_instances.append(auto_mesh)

	# 如果仍然没有找到，警告并返回
	if mesh_instances.is_empty():
		push_warning("CueTrail: Cannot find any target mesh for trail")
		return

	# 4. 创建残影生成器数据
	var trail_data = {
		"target": target_3d,
		"meshes": mesh_instances,
		"timer": 0.0,
		"is_active": true
	}
	_active_trails[target_rid] = trail_data

	# 5. 立即为所有 mesh 生成第一个残影
	for mesh_instance in mesh_instances:
		_spawn_ghost(target_3d, mesh_instance)


func _stop(target: Node) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		return

	var target_rid = str((target as Node3D).get_rid())
	_stop_trail_internal(target_rid)

## 生成残影
func _spawn_ghost(target: Node3D, mesh_instance: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_instance) or not is_instance_valid(mesh_instance.mesh):
		return

	# 1. 创建网格实例副本
	var ghost = MeshInstance3D.new()
	ghost.mesh = mesh_instance.mesh

	# 2. 添加到场景树（必须先添加才能设置全局坐标）
	mesh_instance.get_tree().root.add_child(ghost)

	# 3. 设置变换（使用全局变换，脱离父节点）
	ghost.top_level = true
	ghost.global_transform = mesh_instance.global_transform
	# 应用缩放
	var base_scale = mesh_instance.scale
	ghost.scale = Vector3(base_scale.x * ghost_scale, base_scale.y * ghost_scale, base_scale.z * ghost_scale)

	# 4. 设置材质
	if is_instance_valid(ghost_material):
		# 必须 duplicate 材质，否则修改 alpha 会影响所有残影
		var mat = ghost_material.duplicate()
		ghost.material_override = mat
		
		# 设置颜色（如果材质支持）
		mat.set_shader_parameter("albedo", ghost_color)

		# 初始化 alpha_factor（如果材质支持）
		mat.set_shader_parameter("alpha_factor", 1.0)

	# 5. 使用 Tween 驱动消散（Fade Out）
	var tween = ghost.create_tween()
	tween.set_parallel(false)  # 确保顺序执行

	# 淡出效果
	tween.tween_property(ghost.material_override, "shader_parameter/alpha_factor", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 6. 销毁（确保 Tween 完成后才销毁）
	tween.tween_callback(func(): 
		if is_instance_valid(ghost):
			ghost.queue_free()
	)

## 递归查找所有 MeshInstance3D（返回数组）
func _find_all_meshes_recursive(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)

	for child in node.get_children():
		var child_meshes = _find_all_meshes_recursive(child)
		meshes.append_array(child_meshes)

	return meshes

## 查找目标网格
func _find_target_mesh(target: Node3D) -> MeshInstance3D:
	# 尝试从目标节点自身查找
	if target is MeshInstance3D:
		return target as MeshInstance3D

	# 尝试从所有子节点递归查找
	return _find_mesh_recursive(target)

## 递归查找 MeshInstance3D（返回第一个）
func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		var result = _find_mesh_recursive(child)
		if is_instance_valid(result):
			return result

	return null

func _stop_trail_internal(target_rid: String) -> void:
	if not _active_trails.has(target_rid):
		return

	var trail_data = _active_trails[target_rid]
	trail_data["is_active"] = false  # 标记为非激活，停止生成新残影
	_active_trails.erase(target_rid)  # 清理数据（已生成的残影会自然消散）
