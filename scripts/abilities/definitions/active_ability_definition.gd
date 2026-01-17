extends GameplayAbilityDefinition
class_name ActiveAbilityDefinition

## 简易主动技能模板
## 
## 用途：
## 快速创建标准的 "动画 -> 前摇 -> 冷却 -> 效果 -> 后摇" 流程的技能。
## 如果需要更复杂的逻辑，请直接使用基类 GameplayAbilityDefinition 并手动配置 Execution Tree。

@export_group("Quick Config")
@export var animation_name : StringName = &""
@export var animation_speed : float = 1.0
## 技能前摇时间 (伤害生效前的等待)
@export var pre_cast_delay : float = 0.0
## 技能后摇时间 (伤害生效后的僵直)
@export var post_cast_delay : float = 0.0
## 技能冷却时间
@export var cooldown_duration : float = 0.0
## 技能效果列表
@export var effects : Array[GameplayEffect] = []
## 技能状态列表（Buff/Debuff）
@export var statuses : Array[GameplayStatusData] = []
## 状态执行时间
@export var status_execution_time : float = 0.0
## 目标 Key
@export var target_key: String = "targets" # 修正默认为单数，符合直觉
## 目标获取策略
@export var targeting_strategy: TargetingStrategy = null

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
		if not _has_cooldown_feature(instance):
			var cd_feature = CooldownFeature.new()
			cd_feature.cooldown_duration = cooldown_duration
			instance.add_feature(cd_feature.feature_name, cd_feature)

## 检查 Instance 是否已有 CooldownFeature
## [param] instance: GameplayAbilityInstance 技能实例
## [return] bool 是否存在
func _has_cooldown_feature(instance: GameplayAbilityInstance) -> bool:
	var all_features = instance.get_features()
	for feature in all_features:
		if feature is CooldownFeature:
			return true
	return false

## 验证配置的合理性
func _validate_configuration() -> void:
	# 验证：如果配置了 status_execution_time，应该有 statuses
	if status_execution_time > 0.0 and statuses.is_empty():
		push_warning(
			"ActiveAbilityDefinition [%s]: 配置了 status_execution_time (%.2f) 但没有配置 statuses。\n" % [ability_id, status_execution_time] +
			"status_execution_time 将被忽略。"
		)
	
	# 验证：如果配置了 targeting_strategy，应该配置了 effects 或 statuses
	if is_instance_valid(targeting_strategy):
		if effects.is_empty() and statuses.is_empty():
			push_warning(
				"ActiveAbilityDefinition [%s]: 配置了 targeting_strategy 但没有配置 effects 或 statuses。\n" % ability_id +
				"targeting_strategy 可能不会被使用。"
			)
	
	# 验证：前摇和后摇时间应该非负
	if pre_cast_delay < 0.0:
		push_error("ActiveAbilityDefinition [%s]: pre_cast_delay 不能为负数 (%.2f)" % [ability_id, pre_cast_delay])
		pre_cast_delay = 0.0
	
	if post_cast_delay < 0.0:
		push_error("ActiveAbilityDefinition [%s]: post_cast_delay 不能为负数 (%.2f)" % [ability_id, post_cast_delay])
		post_cast_delay = 0.0
	
	# 验证：冷却时间应该非负
	if cooldown_duration < 0.0:
		push_error("ActiveAbilityDefinition [%s]: cooldown_duration 不能为负数 (%.2f)" % [ability_id, cooldown_duration])
		cooldown_duration = 0.0
	
	# 验证：动画速度应该为正
	if animation_speed <= 0.0:
		push_error("ActiveAbilityDefinition [%s]: animation_speed 必须为正数 (%.2f)" % [ability_id, animation_speed])
		animation_speed = 1.0
	
	# 验证：至少应该配置效果或状态
	if effects.is_empty() and statuses.is_empty():
		push_warning(
			"ActiveAbilityDefinition [%s]: 没有配置 effects 或 statuses，技能可能不会产生任何效果。\n" % ability_id +
			"请确保这是预期的行为。"
		)

## 动态构建行为树结构 (构建的是 BTNode 资源图，而不是 Instance)
## [param] include_cooldown: bool 是否在行为树中包含冷却节点（连击段通常不需要）
func _build_default_behavior_tree(include_cooldown: bool = true) -> BTNode:
	var sequence = BTSequence.new()
	var nodes: Array[BTNode] = []

	# 1. 播放动画 (异步，不等待)
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
		
	# 3. 提交冷却 (前摇结束后进CD)
	# 如果没有 CooldownFeature，这个节点会自动忽略
	# 注意：连击段通常不需要单独的CD，只在连击整体结束时应用CD
	if include_cooldown:
		var commit_cd = AbilityNodeCommitCooldown.new()
		commit_cd.node_id = "commit_cooldown"
		nodes.append(commit_cd)
	
	# 4. 查找目标
	if is_instance_valid(targeting_strategy):
		var target_search_node = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
		target_search_node.node_id = "target_search"
		nodes.append(target_search_node)

	# 5. 应用状态（Buff/Debuff）
	if not statuses.is_empty():
		var status_node = AbilityNodeApplyStatus.new()
		status_node.statuses = statuses.duplicate() # 浅拷贝引用
		status_node.target_key = target_key
		status_node.node_id = "apply_status"
		nodes.append(status_node)
		
		if status_execution_time > 0.0:
			var status_wait = BTWait.new()
			status_wait.duration = status_execution_time
			status_wait.node_id = "wait_status_duration"
			nodes.append(status_wait)

	# 6. 应用效果
	if not effects.is_empty():
		var effect_node = AbilityNodeApplyEffect.new()
		effect_node.effects = effects.duplicate() # 浅拷贝引用
		effect_node.target_key = target_key
		effect_node.node_id = "apply_effect"
		nodes.append(effect_node)
		
	# 7. 后摇等待
	if post_cast_delay > 0.0:
		var wait = BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)
	
	# 赋值子节点
	sequence.children = nodes
	sequence.node_id = "ability_sequence"
	return sequence
