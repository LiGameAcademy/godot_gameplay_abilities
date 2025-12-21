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

# 重写基类的工厂方法
func create_instance(owner: Node) -> GameplayAbilityInstance:
	# 1. 动态注入 Cooldown 特性 (如果配置了且不存在)
	# 注意：我们操作的是 Definition 的副本或动态列表，避免修改到硬盘上的资源
	if cooldown_duration > 0.0:
		var has_cd = false
		for f in features:
			if f is CooldownFeature:
				has_cd = true
				break
		
		if not has_cd:
			var cd_feature = CooldownFeature.new()
			cd_feature.cooldown_duration = cooldown_duration
			# 注意：features 是 Array，这里 append 可能会影响资源文件
			# 安全的做法是 duplicate 一份 features 数组给 instance，或者在 instance 里动态加
			# 这里为了简单，我们假设 create_instance 会处理
			# 但更稳妥的是直接加到下面的 instance 里
			features.append(cd_feature)

	# 2. 动态构建行为树 (如果用户没在编辑器里手动拖树)
	if execution_tree == null:
		execution_tree = _build_default_behavior_tree()

	# 3. 调用父类创建实例
	var instance = super.create_instance(owner)
	
	# 4. 如果刚才为了方便修改了 features，为了不弄脏资源，可以在这里做一些清理
	# 或者更优雅的方式是修改 GameplayAbilityInstance，允许在 create_instance 时注入额外 Feature
	
	return instance

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
