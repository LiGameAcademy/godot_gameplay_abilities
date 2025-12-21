extends GameplayAbilityDefinition
class_name ProjectileAbilityDefinition

## 投射物技能配置模板
## 
## 用途：
## 快速创建标准的 "动画 -> 前摇 -> 冷却 -> 查找目标 -> 转向目标 -> 发射投射物 -> 后摇" 流程的技能。
## 支持投射物撞击时生成魔法阵（可选）。
## 
## 如果需要更复杂的逻辑，请直接使用基类 GameplayAbilityDefinition 并手动配置 Execution Tree。

@export_group("Quick Config")
@export var animation_name : StringName = &""
@export var animation_speed : float = 1.0
## 技能前摇时间（伤害生效前的等待）
@export var pre_cast_delay : float = 0.0
## 技能后摇时间（伤害生效后的僵直）
@export var post_cast_delay : float = 0.0
## 技能冷却时间
@export var cooldown_duration : float = 0.0

@export_group("Projectile Settings")
## 投射物数据（包含场景、速度、生命周期、穿透等配置）
@export var projectile_data: ProjectileData = null
## 发射数量（多重施法）
@export var projectile_count: int = 1
## 散射角度（度，0 表示不散射）
@export var spread_angle: float = 0.0
## 枪口挂点名（用于定位发射点，如 "body", "muzzle"）
@export var muzzle_attachment_point: StringName = &"body"

@export_group("Targeting")
## 目标获取策略（用于查找目标）
@export var targeting_strategy: TargetingStrategy = null
## 是否在发射前转向目标位置（鼠标位置或目标节点）
@export var face_target: bool = true
## 转向速度（弧度/秒，0 或负数表示瞬间转向）
@export var face_target_rotation_speed: float = 12.0

@export_group("Magic Field (On Impact)")
## 撞击时产生的魔法阵（可选）
## 如果配置了，投射物撞击时会自动生成魔法阵
@export var impact_magic_field_data: MagicFieldData = null
## 等待撞击的超时时间（秒，0 表示不超时）
@export var impact_wait_timeout: float = 10.0

## 创建技能实例
func create_instance(owner: Node) -> GameplayAbilityInstance:
	# 1. 动态注入 Cooldown 特性（如果配置了且不存在）
	if cooldown_duration > 0.0:
		var has_cd = false
		for f in features:
			if f is CooldownFeature:
				has_cd = true
				break
		
		if not has_cd:
			var cd_feature = CooldownFeature.new()
			cd_feature.cooldown_duration = cooldown_duration
			features.append(cd_feature)

	# 2. 动态构建行为树（如果用户没在编辑器里手动拖树）
	if execution_tree == null:
		execution_tree = _build_default_behavior_tree()

	# 3. 调用父类创建实例
	return super.create_instance(owner)

## 动态构建行为树结构
## 构建的是 BTNode 资源图，而不是 Instance
func _build_default_behavior_tree() -> BTNode:
	var sequence = BTSequence.new()
	var nodes: Array[BTNode] = []

	# 1. 播放动画（异步，不等待）
	if not animation_name.is_empty():
		var anim_node = AbilityNodePlayAnimation.new()
		anim_node.animation_name = animation_name
		anim_node.animation_speed = animation_speed
		anim_node.wait_for_finish = false 
		anim_node.node_id = "play_animation"
		nodes.append(anim_node)
	
	# 2. 前摇等待
	if pre_cast_delay > 0.0:
		var wait = BTWait.new()
		wait.duration = pre_cast_delay
		wait.node_id = "pre_cast_delay"
		nodes.append(wait)
		
	# 3. 提交冷却（前摇结束后进CD）
	if cooldown_duration > 0.0:
		var commit_cd = AbilityNodeCommitCooldown.new()
		commit_cd.node_id = "commit_cooldown"
		nodes.append(commit_cd)
	
	# 4. 查找目标
	if is_instance_valid(targeting_strategy):
		var target_search_node = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
		target_search_node.node_id = "target_search"
		nodes.append(target_search_node)

	# 5. 转向目标位置（如果配置了）
	# 注意：AbilityNodeFaceTarget 会自动从 Context.custom_data.target_position 获取鼠标位置
	if face_target:
		var face_target_node = AbilityNodeFaceTarget.new()
		face_target_node.instant = (face_target_rotation_speed <= 0.0)
		face_target_node.rotation_speed = face_target_rotation_speed
		face_target_node.node_id = "face_target"
		nodes.append(face_target_node)

	# 6. 发射投射物（核心逻辑）
	if is_instance_valid(projectile_data):
		if is_instance_valid(impact_magic_field_data):
			# 配置了魔法阵：使用并行节点同时执行发射和监听
			nodes.append(_build_projectile_with_magic_field())
		else:
			# 没有魔法阵：直接发射投射物
			nodes.append(_build_spawn_projectile_node())
		
	# 7. 后摇等待
	if post_cast_delay > 0.0:
		var wait = BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)
	
	# 组装序列
	sequence.children = nodes
	sequence.node_id = "projectile_ability_sequence"
	return sequence

## 构建投射物发射节点
func _build_spawn_projectile_node() -> BTNode:
	var spawn_node = AbilityNodeSpawnProjectile.new()
	spawn_node.projectile_data = projectile_data
	spawn_node.projectile_count = projectile_count
	spawn_node.spread_angle = spread_angle
	spawn_node.muzzle_attachment_point = muzzle_attachment_point
	spawn_node.node_id = "spawn_projectile"
	return spawn_node

## 构建投射物发射 + 魔法阵生成的并行节点
## 
## 设计说明：
## - 投射物发射节点会立即返回 SUCCESS（发射完成）
## - 等待撞击节点会返回 RUNNING（等待信号）
## - 使用 SUCCEED_ON_ALL 策略，但让投射物发射节点在发射后返回 RUNNING 直到超时
## - 这样两个分支都会保持 RUNNING 状态，直到撞击发生或超时
## 
## 更好的方案：使用序列结构，先发射投射物，然后等待撞击
func _build_projectile_with_magic_field() -> BTNode:
	# 方案：使用序列结构，先发射投射物，然后等待撞击并生成魔法阵
	# 这样逻辑更清晰，不会因为并行策略导致问题
	var sequence = BTSequence.new()
	sequence.node_id = "projectile_with_magic_field_sequence"
	
	# 1. 发射投射物（立即完成）
	sequence.children.append(_build_spawn_projectile_node())
	
	# 2. 等待撞击并生成魔法阵
	var impact_sequence = BTSequence.new()
	impact_sequence.node_id = "impact_magic_field_sequence"
	
	# 等待投射物撞击（可能超时）
	var wait_impact_node = BTWaitSignal.new()
	wait_impact_node.timeout = impact_wait_timeout
	wait_impact_node.signal_key = "projectile_impact_triggered"
	wait_impact_node.consume_signal = true
	wait_impact_node.node_id = "wait_projectile_impact"
	impact_sequence.children.append(wait_impact_node)
	
	# 生成魔法阵
	var spawn_field_node = AbilityNodeSpawnMagicField.new()
	spawn_field_node.magic_field_data = impact_magic_field_data
	spawn_field_node.position_key = "projectile_impact"
	spawn_field_node.node_id = "spawn_impact_magic_field"
	impact_sequence.children.append(spawn_field_node)
	
	sequence.children.append(impact_sequence)
	
	return sequence
