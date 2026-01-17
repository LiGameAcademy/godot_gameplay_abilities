extends ToggleAbilityDefinition
class_name SacrificeAbilityDefinition

## 献祭技能定义
## 
## 特殊逻辑：
## 1. 开启时消耗初始魔法值
## 2. 开启后周期性消耗生命值（如果不足则自动关闭）
## 3. 周期性对周围敌人造成伤害
## 4. 关闭时触发冷却

@export_group("Sacrifice Settings")
## 周期性消耗的生命值（每秒）
@export var periodic_health_cost: float = 1.0
## 周期性消耗的生命值 Vital ID
@export var periodic_health_vital_id: StringName = &"health"
## 周期性伤害检测半径
@export var damage_radius: float = 3.0
## 周期性伤害倍数
@export var periodic_damage_multiplier: float = 1.5
## 周期性执行间隔（秒）
@export var periodic_interval: float = 1.0
## 区域目标策略（用于查找周围敌人）
@export var area_targeting_strategy: AreaTargetingStrategy = null
## 周期性伤害效果（对周围敌人应用的效果）
@export var periodic_damage_effect: GameplayEffect = null
## 切换时的 Cue（开启时执行，关闭时停止）
@export var toggle_cue: GameplayCue = null

# ========== 行为树缓存（享元模式） ==========
## 缓存的默认行为树（所有实例共享，避免重复构建）
## 只在第一次创建实例时构建，之后所有实例共享
var _cached_sacrifice_tree: BTNode = null

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
	if is_instance_valid(_cached_sacrifice_tree):
		return _cached_sacrifice_tree
	
	# 构建并缓存（只构建一次，之后所有实例共享）
	_cached_sacrifice_tree = _build_default_behavior_tree()
	return _cached_sacrifice_tree

## 在 Instance 中注入 Feature（不修改 Definition，避免资源污染）
## [param] instance: GameplayAbilityInstance 技能实例
func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
	# 注入周期性消耗的 CostFeature（如果配置了）
	if periodic_health_cost > 0.0:
		if not _has_feature(instance, CostFeature, "PeriodicCostFeature"):
			var periodic_cost_feature = CostFeature.new()
			periodic_cost_feature.feature_name = "PeriodicCostFeature"
			
			# 创建周期性生命值消耗
			var health_cost = VitalCost.new()
			health_cost.vital_id = periodic_health_vital_id
			health_cost.amount = periodic_health_cost
			health_cost.allow_overdraft = false  # 不允许透支
			
			periodic_cost_feature.costs.append(health_cost)
			instance.add_feature("PeriodicCostFeature", periodic_cost_feature)

## 检查 Instance 是否已有指定名称的 Feature
## [param] instance: GameplayAbilityInstance 技能实例
## [param] feature_type: GDScript Feature 类型
## [param] feature_name: String Feature 名称（可选，用于精确匹配）
## [return] bool 是否存在
func _has_feature(instance: GameplayAbilityInstance, feature_type: GDScript, feature_name: String = "") -> bool:
	var all_features = instance.get_features()
	for feature in all_features:
		if feature.get_script() == feature_type:
			# 如果指定了名称，需要精确匹配
			if feature_name.is_empty() or feature.feature_name == feature_name:
				return true
	return false

## 验证配置的合理性
func _validate_configuration() -> void:
	# 验证：周期性消耗应该非负
	if periodic_health_cost < 0.0:
		push_error("SacrificeAbilityDefinition [%s]: periodic_health_cost 不能为负数 (%.2f)" % [ability_id, periodic_health_cost])
		periodic_health_cost = 0.0
	
	# 验证：周期性执行间隔应该为正
	if periodic_interval <= 0.0:
		push_error("SacrificeAbilityDefinition [%s]: periodic_interval 必须为正数 (%.2f)" % [ability_id, periodic_interval])
		periodic_interval = 1.0
	
	# 验证：伤害半径应该非负
	if damage_radius < 0.0:
		push_error("SacrificeAbilityDefinition [%s]: damage_radius 不能为负数 (%.2f)" % [ability_id, damage_radius])
		damage_radius = 0.0
	
	# 验证：如果配置了周期性消耗，应该配置了 Vital ID
	if periodic_health_cost > 0.0 and periodic_health_vital_id.is_empty():
		push_warning(
			"SacrificeAbilityDefinition [%s]: 配置了 periodic_health_cost (%.2f) 但没有配置 periodic_health_vital_id。\n" % [ability_id, periodic_health_cost] +
			"周期性消耗可能无法正常工作。"
		)
	
	# 验证：如果配置了周期性伤害效果，应该配置了区域目标策略或伤害半径
	if is_instance_valid(periodic_damage_effect):
		if not is_instance_valid(area_targeting_strategy) and damage_radius <= 0.0:
			push_warning(
				"SacrificeAbilityDefinition [%s]: 配置了 periodic_damage_effect 但没有配置 area_targeting_strategy 或 damage_radius。\n" % ability_id +
				"周期性伤害可能无法正常工作。"
			)

## 动态构建行为树结构 (构建的是 BTNode 资源图，而不是 Instance)
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
	
	# 3. 查找目标
	if is_instance_valid(targeting_strategy):
		var target_search_node = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
		target_search_node.node_id = "target_search"
		nodes.append(target_search_node)

	# 4. 切换逻辑：使用 BTSelector 实现
	var toggle_selector = BTSelector.new()
	toggle_selector.node_id = "toggle_selector"
	
	# 分支1：关闭（技能已激活，需要关闭）
	var turn_off_sequence = BTSequence.new()
	turn_off_sequence.node_id = "turn_off_sequence"
	
	# 检查黑板变量，判断是否为"关闭"操作
	# 注意：toggle_action 变量由 ToggleFeature.on_activate 设置，不需要在这里重复设置
	var check_toggle_action = BTCheckVarAction.new()
	check_toggle_action.key = "toggle_action"
	check_toggle_action.value = "turn_off"
	check_toggle_action.node_id = "check_toggle_action_off"
	turn_off_sequence.children.append(check_toggle_action)

	# 停止 Cue（如果配置了）
	if is_instance_valid(toggle_cue):
		var stop_cue_node = AbilityNodeStopCue.new()
		stop_cue_node.cue_instance_key = "sacrifice_cue_instance"
		stop_cue_node.target_key = target_key
		stop_cue_node.node_id = "stop_toggle_cue"
		turn_off_sequence.children.append(stop_cue_node)

	# 清除激活图标（恢复默认图标）
	if is_instance_valid(icon_when_active):
		var clear_icon_node = BTSetVar.new()
		clear_icon_node.variable_key = "current_icon_id"
		clear_icon_node.value = null
		clear_icon_node.node_id = "clear_active_icon"
		turn_off_sequence.children.append(clear_icon_node)
	
	# 提交冷却（关闭时触发冷却）
	if cooldown_duration > 0.0:
		var commit_cd = AbilityNodeCommitCooldown.new()
		commit_cd.node_id = "commit_cooldown"
		turn_off_sequence.children.append(commit_cd)
	
	toggle_selector.children.append(turn_off_sequence)
	
	# 分支2：开启（应用状态 + 周期性逻辑）
	var turn_on_sequence = BTSequence.new()
	turn_on_sequence.node_id = "turn_on_sequence"
	
	# 检查黑板变量，判断是否为"开启"操作
	var check_toggle_action_on = BTCheckVarAction.new()
	check_toggle_action_on.key = "toggle_action"
	check_toggle_action_on.value = "turn_on"
	check_toggle_action_on.node_id = "check_toggle_action_on"
	turn_on_sequence.children.append(check_toggle_action_on)
	
	# 提交初始消耗（开启时消耗魔法值）
	var commit_cost_node = AbilityNodeCommitCost.new()
	commit_cost_node.node_id = "commit_cost"
	turn_on_sequence.children.append(commit_cost_node)
	
	# 设置激活图标
	if is_instance_valid(icon_when_active):
		var set_icon_node = BTSetVar.new()
		set_icon_node.variable_key = "current_icon_id"
		set_icon_node.value = "active"
		set_icon_node.node_id = "set_active_icon"
		turn_on_sequence.children.append(set_icon_node)

	# 注意：toggle_action 变量由 ToggleFeature.on_activate 设置，不需要在这里重复设置

	# 执行 Cue（如果配置了）
	if is_instance_valid(toggle_cue):
		var execute_cue_node = AbilityNodeExecuteCue.new()
		execute_cue_node.cue = toggle_cue
		execute_cue_node.save_instance_key = "sacrifice_cue_instance"
		execute_cue_node.target_key = target_key
		execute_cue_node.node_id = "execute_toggle_cue"
		turn_on_sequence.children.append(execute_cue_node)

	# 周期性逻辑：检查消耗 + 消耗生命值 + 对敌人造成伤害
	var periodic_repeat = BTRepeatPeriodic.new()
	periodic_repeat.period = periodic_interval
	periodic_repeat.execute_immediately = false  # 等待第一个周期
	periodic_repeat.node_id = "periodic_repeat"
	
	# 周期性执行的序列
	var periodic_sequence = BTSequence.new()
	periodic_sequence.node_id = "periodic_sequence"
	
	# 1. 选择自身目标策略（确保后续节点操作的是自身）
	var self_target_node = AbilityNodeTargetSearch.new()
	var self_targeting = SelfTargetingStrategy.new()
	self_target_node.strategy = self_targeting
	self_target_node.write_to_key = target_key  # 将目标写入到 target_key
	self_target_node.node_id = "select_self_target"
	periodic_sequence.children.append(self_target_node)
	
	# 2. 检查并消耗生命值（如果不足，返回 FAILURE，中断周期性任务）
	var cost_node = AbilityNodeApplyCost.new()
	cost_node.vital_comp_name = "GameplayAttributeComponent"
	cost_node.vital_id = periodic_health_vital_id
	cost_node.cost_amount = periodic_health_cost
	cost_node.allow_overdraft = false
	cost_node.check_only = false  # 检查并消耗
	cost_node.target_key = target_key
	cost_node.node_id = "check_and_apply_periodic_cost"
	periodic_sequence.children.append(cost_node)
	
	# 4. 选择周围目标策略（查找敌人）
	var area_target_node = AbilityNodeTargetSearch.new()
	# 如果用户没有配置策略，创建默认的
	if not is_instance_valid(area_targeting_strategy):
		area_targeting_strategy = AreaTargetingStrategy.new()
		var area_hit_detector = AreaHitDetector.new()
		area_hit_detector.detection_radius = damage_radius
		area_hit_detector.collision_mask = 4  # 敌人层
		area_hit_detector.detection_position_source = AreaHitDetector.DetectionPositionSource.CASTER_POSITION
		area_hit_detector.exclude_caster = true
		area_targeting_strategy.hit_detector = area_hit_detector
	area_target_node.strategy = area_targeting_strategy
	area_target_node.write_to_key = "area_targets"  # 将目标写入到 "area_targets" key
	area_target_node.fail_if_empty = false  # 没有目标时静默成功
	area_target_node.node_id = "select_area_targets"
	periodic_sequence.children.append(area_target_node)
	
	# 5. 对周围敌人应用伤害效果
	if is_instance_valid(periodic_damage_effect):
		var apply_effect_node = AbilityNodeApplyEffect.new()
		apply_effect_node.target_key = "area_targets"  # 从 "area_targets" key 读取目标
		apply_effect_node.effects.append(periodic_damage_effect)  # 直接使用配置的效果
		apply_effect_node.node_id = "apply_area_damage"
		periodic_sequence.children.append(apply_effect_node)
	
	periodic_repeat.child = periodic_sequence
	turn_on_sequence.children.append(periodic_repeat)
	
	toggle_selector.children.append(turn_on_sequence)
	
	nodes.append(toggle_selector)
	
	# 5. 后摇等待
	if post_cast_delay > 0.0:
		var wait = BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)
	
	# 赋值子节点
	sequence.children = nodes
	sequence.node_id = "sacrifice_ability_sequence"
	return sequence
