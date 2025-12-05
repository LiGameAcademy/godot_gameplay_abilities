extends GameplayCueBase
class_name CueTrail

## 拖尾残影 Cue
## 在技能持续期间生成残影效果，适用于冲锋、闪避等快速移动技能
## 基于文档中的 GhostTrailGenerator 实现，但封装为 Cue 组件

@export_group("Trail Settings")
## 残影生成间隔（秒）
@export var emit_interval: float = 0.05
## 残影存活时间（秒）
@export var duration: float = 0.4
## 残影材质（Shader 材质，用于半透明、消散效果）
@export var ghost_material: ShaderMaterial = null
## 是否自动递归查找所有 MeshInstance3D
## 如果为 true，会递归遍历场景树查找所有 MeshInstance3D 节点
## 如果为 false，使用 target_mesh_paths 指定的路径（如果为空则查找第一个）
@export var auto_find_all_meshes: bool = true
## 目标网格路径数组（仅在 auto_find_all_meshes = false 时使用）
## 例如：["Visuals/Body", "Visuals/Weapon", "Visuals/Helmet"]
@export var target_mesh_paths: Array[NodePath] = []
## [已废弃] 单个目标网格路径（向后兼容）
@export var target_mesh_path: NodePath = NodePath("Visuals")

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

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		push_warning("CueTrail: Target is not a valid Node3D")
		return
	
	var target_3d = target as Node3D
	var target_rid = str(target_3d.get_rid())
	
	# 如果已有正在运行的残影，先停止它
	if _active_trails.has(target_rid):
		_stop_trail_internal(target_rid)
	
	# 收集所有目标网格（支持多个 mesh）
	var mesh_instances: Array[MeshInstance3D] = []
	
	if auto_find_all_meshes:
		# 自动递归查找所有 MeshInstance3D
		mesh_instances = _find_all_meshes_recursive(target_3d)
	else:
		# 使用指定路径查找
		var paths_to_check = target_mesh_paths.duplicate()
		if target_mesh_path != NodePath("") and not paths_to_check.has(target_mesh_path):
			paths_to_check.append(target_mesh_path)
		
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
	
	# 5. 创建残影生成器（包含所有 mesh）
	var trail_data = {
		"target": target_3d,
		"meshes": mesh_instances,
		"timer": 0.0,
		"is_active": true
	}
	
	_active_trails[target_rid] = trail_data
	
	# 6. 立即为所有 mesh 生成第一个残影
	for mesh_instance in mesh_instances:
		_spawn_ghost(target_3d, mesh_instance)
	
	# 启动持续生成（通过每帧检查）
	# 注意：这里不直接使用 Timer，而是通过 _process 检查
	# 因为我们需要在 Effect 移除时能够立即停止

func _stop(target: Node) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		return
	
	var target_rid = str((target as Node3D).get_rid())
	_stop_trail_internal(target_rid)

## 停止残影生成（内部方法）
func _stop_trail_internal(target_rid: String) -> void:
	if not _active_trails.has(target_rid):
		return
	
	var trail_data = _active_trails[target_rid]
	trail_data["is_active"] = false
	_active_trails.erase(target_rid)

## 查找目标网格
func _find_target_mesh(target: Node3D) -> MeshInstance3D:
	# 如果指定了路径，尝试从路径获取
	if target_mesh_path != NodePath(""):
		var mesh_node = target.get_node_or_null(target_mesh_path)
		if is_instance_valid(mesh_node) and mesh_node is MeshInstance3D:
			return mesh_node as MeshInstance3D
	
	# 尝试从 Visuals 子节点查找
	var visuals = target.get_node_or_null("Visuals")
	if is_instance_valid(visuals):
		# 查找第一个 MeshInstance3D
		for child in visuals.get_children():
			if child is MeshInstance3D:
				return child as MeshInstance3D
	
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

## 递归查找所有 MeshInstance3D（返回数组）
func _find_all_meshes_recursive(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	
	for child in node.get_children():
		var child_meshes = _find_all_meshes_recursive(child)
		meshes.append_array(child_meshes)
	
	return meshes

## 生成残影
func _spawn_ghost(target: Node3D, mesh_instance: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_instance) or not is_instance_valid(mesh_instance.mesh):
		return
	
	# 1. 创建网格实例副本
	var ghost = MeshInstance3D.new()
	ghost.mesh = mesh_instance.mesh
	
	# 2. 添加到场景树（必须先添加才能设置全局坐标）
	var root = Engine.get_main_loop().root
	if not is_instance_valid(root):
		push_warning("CueTrail: Cannot spawn ghost, no valid root node")
		ghost.queue_free()
		return
	
	root.add_child(ghost)
	
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
	tween.tween_property(ghost.material_override, "shader_parameter/alpha_factor", 0.0, duration) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# 6. 销毁（确保 Tween 完成后才销毁）
	tween.tween_callback(func(): 
		if is_instance_valid(ghost):
			ghost.queue_free()
	)

## 更新残影生成（由 GameplayCueManager 在 _process 中调用）
func _process_trails(delta: float) -> void:
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
			trail_data["timer"] = 0.0
			var meshes = trail_data.get("meshes", []) as Array[MeshInstance3D]
			for mesh in meshes:
				if is_instance_valid(mesh):
					_spawn_ghost(target, mesh)
	
	# 清理无效的残影
	for target_rid in to_remove:
		_active_trails.erase(target_rid)

## 获取骨骼动画快照（高级功能，性能开销较大）
## 捕捉当前骨骼姿态的 mesh，避免残影显示为 T-Pose
## [param] mesh_instance: MeshInstance3D 源网格实例
## [return] ArrayMesh 快照 mesh，如果失败则返回 null
func _get_skeleton_snapshot(mesh_instance: MeshInstance3D) -> ArrayMesh:
	if not is_instance_valid(mesh_instance) or mesh_instance.skeleton == NodePath(""):
		return null
	
	# 获取 Skeleton3D 节点
	var skeleton_path = mesh_instance.skeleton
	var skeleton = mesh_instance.get_node_or_null(skeleton_path) as Skeleton3D
	if not is_instance_valid(skeleton):
		# 尝试从父节点查找
		var parent = mesh_instance.get_parent()
		while is_instance_valid(parent):
			if parent is Skeleton3D:
				skeleton = parent as Skeleton3D
				break
			parent = parent.get_parent()
	
	if not is_instance_valid(skeleton):
		return null
	
	# 获取原始 mesh
	var source_mesh = mesh_instance.mesh
	if not is_instance_valid(source_mesh):
		return null
	
	# 如果是 ArrayMesh，尝试创建快照
	if source_mesh is ArrayMesh:
		var array_mesh = source_mesh as ArrayMesh
		
		# 创建新的 ArrayMesh 作为快照
		var snapshot = ArrayMesh.new()
		
		# 复制所有 surface
		for surface_idx in range(array_mesh.get_surface_count()):
			var surface_arrays = array_mesh.surface_get_arrays(surface_idx)
			var blend_shapes = array_mesh.surface_get_blend_shape_arrays(surface_idx)
			var format = array_mesh.surface_get_format(surface_idx)
			
			# 检查格式标志，判断是否有骨骼和权重数据
			# 在 Godot 4 中，surface_get_arrays() 返回的是 Array，不是 Dictionary
			# 需要通过格式标志来检查，或者直接检查数组索引是否存在
			var has_bones = (format & Mesh.ARRAY_FORMAT_BONES) != 0
			var has_weights = (format & Mesh.ARRAY_FORMAT_WEIGHTS) != 0
			
			# 如果有骨骼权重，应用当前骨骼姿态
			# 同时检查数组长度，确保索引有效
			if has_bones and has_weights and surface_arrays.size() > Mesh.ARRAY_WEIGHTS:
				var vertices = surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var bones = surface_arrays[Mesh.ARRAY_BONES] as PackedInt32Array
				var weights = surface_arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
				
				if vertices.size() > 0 and bones.size() > 0:
					# 应用骨骼变换到顶点
					var transformed_vertices = PackedVector3Array()
					transformed_vertices.resize(vertices.size())
					
					# 遍历每个顶点
					for v_idx in range(vertices.size()):
						var vertex = vertices[v_idx]
						var new_vertex = Vector3.ZERO
						
						# 每个顶点最多有 4 个骨骼影响
						for i in range(4):
							var bone_idx = bones[v_idx * 4 + i] if (v_idx * 4 + i) < bones.size() else -1
							var weight = weights[v_idx * 4 + i] if (v_idx * 4 + i) < weights.size() else 0.0
							
							if bone_idx >= 0 and weight > 0.0 and bone_idx < skeleton.get_bone_count():
								# 获取骨骼的当前姿态（相对于 Skeleton3D 的局部空间）
								var bone_pose = skeleton.get_bone_pose(bone_idx)
								# 获取骨骼的 rest pose（绑定姿态）
								var bone_rest = skeleton.get_bone_rest(bone_idx)
								# 计算从 rest 到当前姿态的变换矩阵
								var bone_transform = bone_pose * bone_rest.affine_inverse()
								# 应用变换到顶点（在绑定空间）
								var transformed_vertex = bone_transform * vertex
								# 加权累加
								new_vertex += transformed_vertex * weight
						
						transformed_vertices[v_idx] = new_vertex
					
					# 更新顶点数组
					surface_arrays[Mesh.ARRAY_VERTEX] = transformed_vertices
			
			# 添加 surface 到快照
			snapshot.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays, blend_shapes, {}, format)
			
			# 复制材质
			var material = array_mesh.surface_get_material(surface_idx)
			if is_instance_valid(material):
				snapshot.surface_set_material(snapshot.get_surface_count() - 1, material)
		
		return snapshot
	
	# 如果不是 ArrayMesh，直接返回原始 mesh（无法快照）
	return null
