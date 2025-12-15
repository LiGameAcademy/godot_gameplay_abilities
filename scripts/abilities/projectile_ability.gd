extends ActiveAbility
class_name ProjectileAbility

## 投射物技能
## 核心思想：载具与弹头分离（Carrier-Payload Pattern）
##
## 架构说明：
## - Ability (发射者): 负责计算"怎么发"（数量、角度、枪口位置），并实例化投射物
## - Projectile (载具): 负责"怎么飞"（直线、追踪、抛物线），以及"撞到了谁"
## - Effect (弹头): 投射物身上携带的"配置清单"，撞击时应用给目标
##
## 设计原则：
## - 不要让 Effect 去生成 Projectile（职责错位）
## - 不要让 Projectile 去生产 Effect（逻辑混乱）
## - 让 Ability 打包好 Effect，交给 Projectile，告诉它送到哪里

@export_group("Projectile Settings")
## 投射物数据（包含场景、速度、生命周期、穿透等配置）
## 业务层可以在编辑器中创建 .tres 资源文件并配置
@export var projectile_data: ProjectileData = null
## 发射数量（多重施法）
@export var projectile_count: int = 1
## 散射角度（度）
@export var spread_angle: float = 0.0
## 枪口挂点名（用于定位发射点）
## 常见挂点名：
## - "root": 根节点位置（默认）
## - "muzzle": 枪口位置
## - "weapon": 武器位置
## - "head": 头顶
## - "body": 身体中心
@export var muzzle_attachment_point: StringName = &"body"


## [重写] 施放技能
## 逻辑：应用直接效果（如发射时对施法者的效果），然后生成投射物
## 投射物携带 statuses 中的效果作为"弹头"传递给目标
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ProjectileAbility: Cannot cast, instigator is not valid")
		return
	
	# 1. 应用直接效果（如发射时对施法者应用buff、消耗资源等）
	# 注意：effects 应用到施法者或通过 targeting_strategy 获取的目标
	_apply_initial_effects(instigator, input_target, context)
	
	# 2. 检查投射物数据
	if not is_instance_valid(projectile_data):
		push_warning("ProjectileAbility: projectile_data is not set for ability %s" % ability_id)
		return
	
	# 3. 检查投射物场景（现在从 projectile_data 获取）
	if not is_instance_valid(projectile_data.projectile_scene):
		push_warning("ProjectileAbility: projectile_scene is not set in projectile_data for ability %s" % ability_id)
		return
	
	# 4. 确定发射基准信息
	var spawn_transform = _get_muzzle_transform(instigator, context)
	
	# 5. 获取追踪目标（用于投射物追踪）
	var target_for_homing: Node3D = _get_homing_target(instigator, input_target, context)
	
	# 6. 计算实际发射数量（支持 Modifier 修改）
	var actual_projectile_count = projectile_count
	# 读取 Modifier 通过 context 传递的额外投射物数量
	actual_projectile_count += context.get("extra_projectiles", 0)
	actual_projectile_count = max(1, actual_projectile_count)  # 至少发射 1 个
	
	# 7. 循环生成投射物
	for i in range(actual_projectile_count):
		var projectile = _spawn_projectile(
			instigator, 
			spawn_transform, 
			projectile_data.duplicate(), 
			target_for_homing, 
			context
		)
		
		# 7. 连接信号（用于超时处理）
		if is_instance_valid(projectile):
			_connect_projectile_signals(projectile, ability_comp, context)
	
	# 注意：投射物是"发射即不管"（Fire and Forget），所以这里不需要阻塞
	# 如果投射物需要阻塞技能完成，可以在 ProjectileBase 中实现
	# 但是，由于投射物的效果是在命中时应用的（不在 _on_cast 中应用），
	# 所以 _pending_statuses 会保持为空，需要立即检查并发出完成信号
	_check_ability_completion()

## 连接投射物信号
## [param] projectile: ProjectileBase 投射物实例
## [param] ability_comp: Node 技能组件
## [param] context: Dictionary 上下文信息
func _connect_projectile_signals(
		projectile: ProjectileBase,
		ability_comp: Node,
		context: Dictionary) -> void:
	if not is_instance_valid(projectile):
		return

	# 连接撞击信号：由 Ability 将状态应用给命中相关目标（通过状态的 hit_detector 与 target_mode 决定）
	projectile.impact_triggered.connect(_on_projectile_impact.bind(ability_comp, context))
	
	# 连接超时信号（如果配置了 timeout_status）
	if is_instance_valid(projectile_data):
		projectile.timeout_triggered.connect(_on_projectile_timeout.bind(ability_comp, context))

## 处理投射物撞击事件
## 当投射物撞击时，投射物已经自己应用了弹头（状态/效果）并处理了穿透逻辑
## Ability 可以在这里处理特殊逻辑（如播放特效、触发额外效果等）
## [param] hit_position: Vector3 撞击位置
## [param] direct_hit_target: Node 直接命中的目标（可选）
## [param] impact_context: Dictionary 撞击上下文（来自 ProjectileBase）
## [param] ability_comp: Node 技能组件
## [param] context: Dictionary 原始施放上下文
func _on_projectile_impact(
		hit_position: Vector3,
		direct_hit_target: Node,
		impact_context: Dictionary,
		ability_comp: Node,
		context: Dictionary) -> void:
	# 投射物已经自己处理了穿透逻辑和销毁决策
	# Ability 可以在这里处理特殊逻辑（如播放特效、触发额外效果等）
	# impact_context["consumed"] 表示投射物是否已被销毁
	var consumed = impact_context.get("consumed", true)
	if consumed:
		print("ProjectileAbility: Projectile consumed after impact")
	else:
		print("ProjectileAbility: Projectile piercing through")

## 处理投射物超时事件
## 当投射物生命周期结束时，在超时位置应用 timeout_status（如果配置了）
## 注意：超时状态会应用到 instigator 上，但状态可以通过 hit_detector 检测超时位置周围的目标
## [param] position: Vector3 超时位置
## [param] timeout_context: Dictionary 超时上下文（来自 ProjectileBase）
## [param] ability_comp: Node 技能组件
## [param] context: Dictionary 原始上下文
func _on_projectile_timeout(
		position: Vector3,
		timeout_context: Dictionary,
		ability_comp: Node,
		context: Dictionary) -> void:
	if not is_instance_valid(projectile_data):
		return
	
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		return
	
	var projectile = timeout_context.get("projectile", null) as ProjectileBase
	if not is_instance_valid(projectile):
		return
	
## 生成投射物
## [param] instigator: Node 施法者
## [param] spawn_transform: Transform3D 发射变换
## [param] data: ProjectileData 投射物数据
## [param] target_node: Node3D 追踪目标（可选）
## [param] context: Dictionary 上下文信息
## [return] ProjectileBase 投射物实例（用于连接信号），如果失败则返回 null
func _spawn_projectile(
		instigator: Node, 
		spawn_transform: Transform3D, 
		data: ProjectileData, 
		target_node: Node3D, 
		context: Dictionary = {}) -> ProjectileBase:
	# 从 ProjectileData 获取场景
	if not is_instance_valid(data) or not is_instance_valid(data.projectile_scene):
		push_error("ProjectileAbility: projectile_scene is not set in projectile_data")
		return null
	
	var projectile = data.projectile_scene.instantiate()
	
	# 类型检查
	if not projectile is ProjectileBase:
		push_error("ProjectileAbility: projectile_scene must be a ProjectileBase, got: %s" % projectile.get_class())
		projectile.queue_free()
		return null
	
	var projectile_base = projectile as ProjectileBase
	
	# 添加到场景（通常加到当前关卡的独立容器中，不要加到角色子节点）
	var level_root = instigator.get_tree().current_scene
	if not is_instance_valid(level_root):
		push_error("ProjectileAbility: Cannot find current scene root")
		projectile_base.queue_free()
		return null
	
	level_root.add_child(projectile_base)
	
	# --- 配置投射物 ---
	
	# A. 设置位置和初始朝向
	# 重要：在设置 instigator 之前设置位置，避免立即碰撞
	projectile_base.global_transform = spawn_transform
	
	# 将投射物稍微向前和向上移动，避免生成在角色内部或贴地
	var forward_offset = -spawn_transform.basis.z * 0.5  # 向前移动0.5单位
	var up_offset = Vector3.UP * 0.5  # 向上移动0.5单位，避免贴地
	projectile_base.global_position += forward_offset + up_offset
	
	# 应用散射（Spread）- 绕 Y 轴随机旋转
	if spread_angle > 0.0:
		var random_angle = deg_to_rad(randf_range(-spread_angle / 2.0, spread_angle / 2.0))
		projectile_base.rotate_y(random_angle)
	
	# B. 注入运行时依赖（必须在 apply_to_projectile 之前设置 instigator）
	# 这样 initialize_velocity 中如果有调试信息，可以正确显示
	projectile_base.instigator = instigator
	projectile_base.target_reference = target_node  # 用于追踪
	
	# C. 应用投射物数据（速度、生命周期、穿透、策略等）
	# 注意：必须在设置 transform 和 instigator 之后调用，因为 _initialize_velocity() 需要正确的朝向
	data.apply_to_projectile(projectile_base)
	
	# 调试日志
	print("ProjectileAbility: Spawned projectile for ability %s (speed: %.1f, strategy: %s)" % [
		ability_id,
		projectile_base.speed,
		projectile_base.movement_strategy.get_class() if is_instance_valid(projectile_base.movement_strategy) else "None"
	])
	
	# 返回投射物实例，供调用者连接信号
	# 注意：不再传递 impact_context，所有上下文信息由 Ability 在信号处理时提供
	return projectile_base

## 获取枪口变换（发射点位置和朝向）
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文信息
## [return] Transform3D 枪口变换
func _get_muzzle_transform(instigator: Node, context: Dictionary) -> Transform3D:
	# 优先级1: 从 Context 获取枪口变换
	var transform = _get_muzzle_transform_from_context(context)
	if transform != null and transform is Transform3D:
		return transform as Transform3D
	
	# 优先级2: 从 Context 获取枪口位置和方向
	transform = _get_muzzle_transform_from_position_direction(context)
	if transform != null and transform is Transform3D:
		return transform as Transform3D
	
	# 优先级3: 通过挂点名查找枪口位置
	transform = _get_muzzle_transform_from_attachment_point(instigator, context)
	if transform != null and transform is Transform3D:
		return transform as Transform3D
	
	# 优先级4: 使用默认位置和面朝方向
	return _get_muzzle_transform_default(instigator, context)

## 优先级1: 从 Context 获取枪口变换
## [param] context: Dictionary 上下文信息
## [return] Transform3D 枪口变换，如果不存在则返回 null（使用 Variant 类型）
func _get_muzzle_transform_from_context(context: Dictionary) -> Variant:
	if context.has("muzzle_transform") and context["muzzle_transform"] is Transform3D:
		return context["muzzle_transform"] as Transform3D
	return null

## 优先级2: 从 Context 获取枪口位置和方向
## [param] context: Dictionary 上下文信息
## [return] Transform3D 枪口变换，如果不存在则返回 null（使用 Variant 类型）
func _get_muzzle_transform_from_position_direction(context: Dictionary) -> Variant:
	if context.has("muzzle_position") and context.has("muzzle_direction"):
		var pos = context["muzzle_position"] as Vector3
		var dir = (context["muzzle_direction"] as Vector3).normalized()
		return _build_transform_from_direction(pos, dir)
	return null

## 优先级3: 通过挂点名查找枪口位置
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文信息
## [return] Transform3D 枪口变换，如果不存在则返回 null（使用 Variant 类型）
func _get_muzzle_transform_from_attachment_point(instigator: Node, context: Dictionary) -> Variant:
	if muzzle_attachment_point == &"":
		return null
	
	var muzzle_position = _get_attachment_point_position(instigator, muzzle_attachment_point)
	if muzzle_position == Vector3.ZERO and muzzle_attachment_point != &"root":
		return null
	
	# 获取面朝方向
	var facing_direction = _get_facing_direction(instigator, context)
	return _build_transform_from_direction(muzzle_position, facing_direction)

## 优先级4: 使用默认位置和面朝方向
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文信息
## [return] Transform3D 枪口变换
func _get_muzzle_transform_default(instigator: Node, context: Dictionary) -> Transform3D:
	# 获取面朝方向
	var facing_direction = _get_facing_direction(instigator, context)
	
	# 获取发射位置（优先使用 visuals 节点的位置，因为 visuals 负责表现）
	var spawn_position: Vector3
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		
		# 尝试从 visuals 子节点获取位置（Player 等角色使用 visuals 节点）
		if instigator_3d.has_node("Visuals"):
			var visuals = instigator_3d.get_node("Visuals")
			if visuals is Node3D:
				var visuals_3d = visuals as Node3D
				spawn_position = visuals_3d.global_position
				# 提高发射高度（角色中心 + 0.5单位，大约在胸部位置）
				spawn_position.y += 0.5
			else:
				spawn_position = instigator_3d.global_position
				spawn_position.y += 0.5
		else:
			# 如果没有 visuals 节点，使用根节点位置
			spawn_position = instigator_3d.global_position
			# 提高发射高度（角色中心 + 0.5单位，大约在胸部位置）
			spawn_position.y += 0.5
	else:
		spawn_position = Vector3.ZERO
	
	return _build_transform_from_direction(spawn_position, facing_direction)

## 获取面朝方向
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文信息
## [return] Vector3 面朝方向（已归一化）
func _get_facing_direction(instigator: Node, context: Dictionary) -> Vector3:
	# 优先级1: 从 context 获取 facing_direction（Vector3）
	if context.has("facing_direction") and context["facing_direction"] is Vector3:
		return (context["facing_direction"] as Vector3).normalized()
	
	# 优先级2: 从 context 获取 facing_angle（float），转换为方向
	# 注意：这个角度应该与 visuals 节点的 rotation.y 一致
	# 在 Player 中，visuals.rotation.y 使用 atan2(input_dir.x, input_dir.y) + PI 计算
	# 由于角度系统已改为 +PI，方向向量公式需要相应调整
	# angle = base_angle + PI，所以 direction = Vector3(-sin(angle), 0.0, -cos(angle))
	if context.has("facing_angle") and context["facing_angle"] is float:
		var angle = context["facing_angle"] as float
		# 将角度转换为方向向量（XZ 平面）
		# 注意：这个公式与 visuals.rotation.y 的角度系统一致（已加 PI，-Z 为前方）
		var direction = Vector3(-sin(angle), 0.0, -cos(angle))
		return direction.normalized()
	
	# 优先级3: 从 context 获取 target_position，计算方向
	if context.has("target_position") and context["target_position"] is Vector3:
		var target_pos = context["target_position"] as Vector3
		if instigator is Node3D:
			var instigator_3d = instigator as Node3D
			var direction = (target_pos - instigator_3d.global_position).normalized()
			if direction.length_squared() > 0.01:
				return direction
	
	# 优先级4: 从 instigator 获取
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		if instigator_3d.has_method("get_facing_direction"):
			return instigator_3d.get_facing_direction()
		else:
			# 尝试从 visuals 子节点获取朝向（Player 等角色使用 visuals 节点旋转）
			if instigator_3d.has_node("Visuals"):
				var visuals = instigator_3d.get_node("Visuals")
				if visuals is Node3D:
					var visuals_3d = visuals as Node3D
					# 使用 visuals 的旋转计算方向
					# 注意：visuals.rotation.y 已包含 +PI 偏移（适配 -Z 为前方），所以方向向量公式需要调整
					var angle = visuals_3d.rotation.y
					var direction = Vector3(-sin(angle), 0.0, -cos(angle))
					if direction.length_squared() > 0.01:
						return direction.normalized()
			
			# 使用 transform 的 -Z 轴（Godot 默认朝向）
			return -instigator_3d.global_transform.basis.z
	
	# 默认方向
	return Vector3.FORWARD

## 从位置和方向构建变换
## [param] position: Vector3 位置
## [param] direction: Vector3 方向（会被归一化）
## [return] Transform3D 变换
func _build_transform_from_direction(position: Vector3, direction: Vector3) -> Transform3D:
	var dir = direction.normalized()
	var up = Vector3.UP
	var right = dir.cross(up).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	up = right.cross(dir).normalized()
	var basis = Basis(right, up, -dir)
	return Transform3D(basis, position)

## 获取挂点位置（使用 AttachmentPointUtils 工具类）
## [param] target: Node 目标节点
## [param] attachment_point: StringName 挂点名
## [return] Vector3 挂点位置（世界坐标）
func _get_attachment_point_position(target: Node, attachment_point: StringName) -> Vector3:
	# 使用 AttachmentPointUtils 单例（AutoLoad 后可以直接通过名称访问）
	return AttachmentPointUtils.get_attachment_point_position(target, attachment_point)

## 获取追踪目标（用于投射物追踪）
## 符合开闭原则：通过 context 传递追踪目标，避免硬编码目标解析逻辑
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标
## [param] context: Dictionary 上下文信息
## [return] Node3D 追踪目标，如果不存在则返回 null（投射物将直线飞行）
func _get_homing_target(instigator: Node, input_target: Node, context: Dictionary) -> Node3D:
	# 优先级1: 从 context 获取追踪目标（业务层可以显式指定）
	# 这样设计允许业务层通过 context 传递任意类型的追踪目标，无需修改框架代码
	if context.has("homing_target"):
		var homing_target = context["homing_target"]
		if is_instance_valid(homing_target) and homing_target is Node3D:
			return homing_target as Node3D
	
	# 优先级2: 使用 input_target（如果存在且是 Node3D）
	if is_instance_valid(input_target) and input_target is Node3D:
		return input_target as Node3D
	
	# 优先级3: 通过 targeting_strategy 解析（如果配置了）
	# 注意：这里只获取第一个目标，用于追踪
	# 如果业务层需要更复杂的追踪逻辑，应该通过 context["homing_target"] 传递
	if is_instance_valid(targeting_strategy):
		var resolved_targets = targeting_strategy.resolve_targets(instigator, input_target, context)
		if not resolved_targets.is_empty() and is_instance_valid(resolved_targets[0]):
			var first_target = resolved_targets[0]
			# 确保目标是 Node3D（追踪需要 3D 位置）
			if first_target is Node3D:
				return first_target as Node3D
	
	# 无追踪目标，投射物将直线飞行
	return null
