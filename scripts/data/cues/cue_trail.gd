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
## 目标网格路径数组（支持多个 MeshInstance3D）
## 例如：["Visuals/Body", "Visuals/Weapon", "Visuals/Helmet"]
## 如果为空，会自动查找第一个 MeshInstance3D
@export var target_mesh_paths: Array[NodePath] = []
## [已废弃] 单个目标网格路径（向后兼容）
## 如果设置了此属性，会自动添加到 target_mesh_paths 中
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
	
	# 1. 处理向后兼容：如果设置了 target_mesh_path，添加到数组中
	var paths_to_check = target_mesh_paths.duplicate()
	if target_mesh_path != NodePath("") and not paths_to_check.has(target_mesh_path):
		paths_to_check.append(target_mesh_path)
	
	# 2. 如果指定了路径，从路径获取
	if not paths_to_check.is_empty():
		for path in paths_to_check:
			if path == NodePath(""):
				continue
			var mesh_node = target_3d.get_node_or_null(path)
			if is_instance_valid(mesh_node) and mesh_node is MeshInstance3D:
				mesh_instances.append(mesh_node as MeshInstance3D)
	
	# 3. 如果没有找到任何 mesh，自动查找
	if mesh_instances.is_empty():
		var auto_mesh = _find_target_mesh(target_3d)
		if is_instance_valid(auto_mesh):
			mesh_instances.append(auto_mesh)
	
	# 4. 如果仍然没有找到，警告并返回
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

## 递归查找 MeshInstance3D
func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	
	for child in node.get_children():
		var result = _find_mesh_recursive(child)
		if is_instance_valid(result):
			return result
	
	return null

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
	
	# 淡出效果
	tween.tween_property(ghost.material_override, "shader_parameter/alpha_factor", 0.0, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# 6. 销毁
	tween.tween_callback(ghost.queue_free)

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
