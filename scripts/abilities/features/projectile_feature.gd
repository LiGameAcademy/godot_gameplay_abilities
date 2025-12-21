extends GameplayAbilityFeature
class_name ProjectileFeature

## 投射物特性
## 生成投射物，投射物携带 statuses 中的效果作为"弹头"传递给目标
##
## 使用方式：
## ```gdscript
## var ability = ActiveAbility.new()
## var projectile_feature = ProjectileFeature.new()
## projectile_feature.projectile_data = my_projectile_data
## ability.features.append(projectile_feature)
## ```

@export_group("Projectile Settings")
## 投射物数据（包含场景、速度、生命周期、穿透等配置）
@export var projectile_data: ProjectileData = null
## 发射数量（多重施法）
@export var projectile_count: int = 1
## 散射角度（度）
@export var spread_angle: float = 0.0
## 枪口挂点名（用于定位发射点）
@export var muzzle_attachment_point: StringName = &"body"

func _init() -> void:
	super("ProjectileFeature")

## [重写] 技能实际生效时的处理
func on_cast(ability: GameplayAbility, context: AbilityContext) -> void:
	var ability_comp = context.ability_comp
	var input_target = context.input_target
	var instigator = context.instigator
	
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		push_warning("ProjectileFeature: Cannot cast, invalid ability_comp or instigator")
		return
	
	# 检查投射物数据
	if not is_instance_valid(projectile_data):
		push_warning("ProjectileFeature: projectile_data is not set for ability %s" % ability.ability_id)
		return
	
	# 检查投射物场景
	if not is_instance_valid(projectile_data.projectile_scene):
		push_warning("ProjectileFeature: projectile_scene is not set in projectile_data for ability %s" % ability.ability_id)
		return
	
	# 确定发射基准信息（使用 ProjectileAbility 的辅助方法）
	var spawn_transform = _get_muzzle_transform(instigator, context.to_dict())
	
	# 获取追踪目标
	var target_for_homing: Node3D = _get_homing_target(instigator, input_target, context.to_dict())
	
	# 计算实际发射数量（支持 Modifier 修改）
	var actual_projectile_count = projectile_count
	actual_projectile_count += context.extra_projectiles
	actual_projectile_count = max(1, actual_projectile_count)
	
	# 计算散射角度分布
	var effective_spread_angle = spread_angle
	if actual_projectile_count > 1 and spread_angle <= 0.0:
		effective_spread_angle = (actual_projectile_count - 1) * 15.0
	
	# 循环生成投射物
	for i in range(actual_projectile_count):
		var angle_offset: float = 0.0
		if actual_projectile_count > 1 and effective_spread_angle > 0.0:
			var half_spread = effective_spread_angle / 2.0
			if actual_projectile_count > 1:
				var t = float(i) / float(actual_projectile_count - 1)
				angle_offset = lerp(-half_spread, half_spread, t)
		
		var projectile = _spawn_projectile(
			instigator,
			spawn_transform,
			projectile_data.duplicate(),
			target_for_homing,
			context.to_dict(),
			angle_offset
		)
		
		if is_instance_valid(projectile):
			_connect_projectile_signals(projectile, ability_comp, context.to_dict())
	
	# 投射物是"发射即不管"，立即完成技能
	ability._ability_completion()

## [重写] 获取特性描述
func get_description() -> String:
	if not is_instance_valid(projectile_data):
		return "投射物特性（未配置）"
	return "投射物特性（数量: %d）" % projectile_count

## 生成投射物（从 ProjectileAbility 迁移）
func _spawn_projectile(
		instigator: Node,
		spawn_transform: Transform3D,
		data: ProjectileData,
		target_node: Node3D,
		context: Dictionary = {},
		angle_offset: float = 0.0) -> ProjectileBase:
	if not is_instance_valid(data) or not is_instance_valid(data.projectile_scene):
		push_error("ProjectileFeature: projectile_scene is not set in projectile_data")
		return null
	
	var projectile = data.projectile_scene.instantiate()
	if not projectile is ProjectileBase:
		push_error("ProjectileFeature: projectile_scene must be a ProjectileBase")
		projectile.queue_free()
		return null
	
	var projectile_base = projectile as ProjectileBase
	
	var level_root = instigator.get_tree().current_scene
	if not is_instance_valid(level_root):
		push_error("ProjectileFeature: Cannot find current scene root")
		projectile_base.queue_free()
		return null
	
	level_root.add_child(projectile_base)
	
	projectile_base.global_transform = spawn_transform
	var forward_offset = -spawn_transform.basis.z * 0.5
	var up_offset = Vector3.UP * 0.5
	projectile_base.global_position += forward_offset + up_offset
	
	if abs(angle_offset) > 0.001:
		var angle_rad = deg_to_rad(angle_offset)
		projectile_base.rotate_y(angle_rad)
	elif spread_angle > 0.0:
		var random_angle = deg_to_rad(randf_range(-spread_angle / 2.0, spread_angle / 2.0))
		projectile_base.rotate_y(random_angle)
	
	projectile_base.instigator = instigator
	projectile_base.target_reference = target_node
	data.apply_to_projectile(projectile_base)
	
	return projectile_base

## 连接投射物信号（从 ProjectileAbility 迁移）
func _connect_projectile_signals(
		projectile: ProjectileBase,
		ability_comp: Node,
		context: Dictionary) -> void:
	if not is_instance_valid(projectile):
		return
	
	projectile.impact_triggered.connect(_on_projectile_impact.bind(ability_comp, context))
	
	if is_instance_valid(projectile_data):
		projectile.timeout_triggered.connect(_on_projectile_timeout.bind(ability_comp, context))

## 获取枪口变换（从 ProjectileAbility 迁移，简化版）
func _get_muzzle_transform(instigator: Node, context: Dictionary) -> Transform3D:
	# 简化实现：使用默认位置和面朝方向
	var facing_direction = _get_facing_direction(instigator, context)
	var spawn_position: Vector3
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		if instigator_3d.has_node("Visuals"):
			var visuals = instigator_3d.get_node("Visuals")
			if visuals is Node3D:
				spawn_position = (visuals as Node3D).global_position
				spawn_position.y += 0.5
			else:
				spawn_position = instigator_3d.global_position
				spawn_position.y += 0.5
		else:
			spawn_position = instigator_3d.global_position
			spawn_position.y += 0.5
	else:
		spawn_position = Vector3.ZERO
	
	return _build_transform_from_direction(spawn_position, facing_direction)

## 获取面朝方向（从 ProjectileAbility 迁移，简化版）
func _get_facing_direction(instigator: Node, context: Dictionary) -> Vector3:
	if context.has("facing_direction") and context["facing_direction"] is Vector3:
		return (context["facing_direction"] as Vector3).normalized()
	
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		if instigator_3d.has_node("Visuals"):
			var visuals = instigator_3d.get_node("Visuals")
			if visuals is Node3D:
				var visuals_3d = visuals as Node3D
				var angle = visuals_3d.rotation.y
				var direction = Vector3(-sin(angle), 0.0, -cos(angle))
				if direction.length_squared() > 0.01:
					return direction.normalized()
		return -instigator_3d.global_transform.basis.z
	
	return Vector3.FORWARD

## 从位置和方向构建变换
func _build_transform_from_direction(position: Vector3, direction: Vector3) -> Transform3D:
	var dir = direction.normalized()
	var up = Vector3.UP
	var right = dir.cross(up).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	up = right.cross(dir).normalized()
	var basis = Basis(right, up, -dir)
	return Transform3D(basis, position)

## 获取追踪目标
func _get_homing_target(instigator: Node, input_target: Node, context: Dictionary) -> Node3D:
	if context.has("homing_target"):
		var homing_target = context["homing_target"]
		if is_instance_valid(homing_target) and homing_target is Node3D:
			return homing_target as Node3D
	
	if is_instance_valid(input_target) and input_target is Node3D:
		return input_target as Node3D
	
	return null

## 处理投射物撞击事件
func _on_projectile_impact(
		hit_position: Vector3,
		direct_hit_target: Node,
		impact_context: Dictionary,
		ability_comp: Node,
		context: Dictionary) -> void:
	var consumed = impact_context.get("consumed", true)
	if consumed:
		print("ProjectileFeature: Projectile consumed after impact")
	else:
		print("ProjectileFeature: Projectile piercing through")

## 处理投射物超时事件
func _on_projectile_timeout(
		position: Vector3,
		timeout_context: Dictionary,
		ability_comp: Node,
		context: Dictionary) -> void:
	# 超时处理逻辑（如果需要）
	pass
