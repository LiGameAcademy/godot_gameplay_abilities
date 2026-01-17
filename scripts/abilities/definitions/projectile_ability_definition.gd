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

# ========== 行为树缓存（享元模式） ==========
## 缓存的默认行为树（所有实例共享，避免重复构建）
## 只在第一次创建实例时构建，之后所有实例共享
var _cached_default_tree: BTNode = null

## 重写基类的工厂方法
## 在创建实例时自动注入 Feature 和构建行为树（不修改 Definition，避免资源污染）
func create_instance(owner: Node) -> GameplayAbilityInstance:
	# 1. 验证配置
	_validate_configuration()
	
	# 2. 获取执行树（优先使用用户配置，否则使用缓存的默认树）
	var tree_to_use = _get_execution_tree()
	
	# 3. 临时设置 execution_tree（仅用于创建 Instance，不污染资源）
	var original_tree = execution_tree
	execution_tree = tree_to_use
	
	# 4. 调用父类创建实例（这会复制 features 到 instance）
	var instance = super(owner)
	
	# 5. 立即恢复 execution_tree（避免资源污染）
	execution_tree = original_tree
	
	# 6. 在 Instance 中动态注入 Feature（不修改 Definition，避免资源污染）
	_inject_features_to_instance(instance)
	
	return instance

## 获取执行树（优先使用用户配置，否则使用缓存的默认树）
## 符合享元模式：所有实例共享同一个行为树
## [return] BTNode 执行树
func _get_execution_tree() -> BTNode:
	# 如果用户手动配置了，使用用户的
	if is_instance_valid(execution_tree):
		return execution_tree
	
	# 如果已缓存，使用缓存的（享元模式）
	if is_instance_valid(_cached_default_tree):
		return _cached_default_tree
	
	# 构建并缓存（只构建一次，之后所有实例共享）
	_cached_default_tree = _build_default_behavior_tree()
	return _cached_default_tree

## 在 Instance 中注入 Feature（不修改 Definition，避免资源污染）
## [param] instance: GameplayAbilityInstance 技能实例
func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
	# 注入 CooldownFeature（如果配置了冷却时间且不存在）
	if cooldown_duration > 0.0:
		if not _has_feature(instance, CooldownFeature):
			var cd_feature = CooldownFeature.new()
			cd_feature.cooldown_duration = cooldown_duration
			instance.add_feature(cd_feature.feature_name, cd_feature)

## 检查 Instance 是否已有指定类型的 Feature
## [param] instance: GameplayAbilityInstance 技能实例
## [param] feature_type: GDScript Feature 类型
## [return] bool 是否存在
func _has_feature(instance: GameplayAbilityInstance, feature_type: GDScript) -> bool:
	var all_features = instance.get_features()
	for feature in all_features:
		if feature.get_script() == feature_type:
			return true
	return false

## 验证配置的合理性
func _validate_configuration() -> void:
	# 验证：前摇和后摇时间应该非负
	if pre_cast_delay < 0.0:
		push_error("ProjectileAbilityDefinition [%s]: pre_cast_delay 不能为负数 (%.2f)" % [ability_id, pre_cast_delay])
		pre_cast_delay = 0.0
	
	if post_cast_delay < 0.0:
		push_error("ProjectileAbilityDefinition [%s]: post_cast_delay 不能为负数 (%.2f)" % [ability_id, post_cast_delay])
		post_cast_delay = 0.0
	
	# 验证：冷却时间应该非负
	if cooldown_duration < 0.0:
		push_error("ProjectileAbilityDefinition [%s]: cooldown_duration 不能为负数 (%.2f)" % [ability_id, cooldown_duration])
		cooldown_duration = 0.0
	
	# 验证：动画速度应该为正
	if animation_speed <= 0.0:
		push_error("ProjectileAbilityDefinition [%s]: animation_speed 必须为正数 (%.2f)" % [ability_id, animation_speed])
		animation_speed = 1.0
	
	# 验证：投射物数量应该为正
	if projectile_count <= 0:
		push_error("ProjectileAbilityDefinition [%s]: projectile_count 必须为正数 (%d)" % [ability_id, projectile_count])
		projectile_count = 1
	
	# 验证：散射角度应该非负
	if spread_angle < 0.0:
		push_error("ProjectileAbilityDefinition [%s]: spread_angle 不能为负数 (%.2f)" % [ability_id, spread_angle])
		spread_angle = 0.0
	
	# 验证：应该配置投射物数据
	if not is_instance_valid(projectile_data):
		push_warning(
			"ProjectileAbilityDefinition [%s]: 没有配置 projectile_data，技能可能不会产生任何效果。\n" % ability_id +
			"请确保这是预期的行为。"
		)
	
	# 验证：如果配置了魔法阵，应该配置了投射物数据
	if is_instance_valid(impact_magic_field_data) and not is_instance_valid(projectile_data):
		push_warning(
			"ProjectileAbilityDefinition [%s]: 配置了 impact_magic_field_data 但没有配置 projectile_data。\n" % ability_id +
			"impact_magic_field_data 可能不会被使用。"
		)

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
		# 【改进】如果配置了魔法阵，直接传递给投射物节点
		# 投射物会在撞击时自动生成魔法阵，不依赖技能行为树
		# 这样即使施法者死亡，魔法阵也能正常生成
		var spawn_node = _build_spawn_projectile_node()
		if is_instance_valid(impact_magic_field_data):
			# 将魔法阵数据传递给投射物节点
			spawn_node.impact_magic_field_data = impact_magic_field_data
		nodes.append(spawn_node)
		
	# 7. 后摇等待
	if post_cast_delay > 0.0:
		var wait = BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)
	
	# 赋值子节点
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
