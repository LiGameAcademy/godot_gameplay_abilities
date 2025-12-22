extends GameplayAbilityDefinition
class_name ToggleAbilityDefinition

## 切换类技能配置模板
## 
## 用途：
## 快速创建切换类技能（Toggle Ability），可以在"开"和"关"状态之间切换。
## 点击技能时：
## - 如果技能未激活，则开启（应用状态、消耗资源）
## - 如果技能已激活，则关闭（移除状态、触发冷却）
## 
## 注意：
## - 切换逻辑由 ToggleFeature 处理，它会设置黑板中的 "toggle_action" 变量
## - 行为树通过检查 "toggle_action" 变量来决定执行开启还是关闭逻辑
## 
## 如果需要更复杂的逻辑，请直接使用基类 GameplayAbilityDefinition 并手动配置 Execution Tree。

@export_group("Quick Config")
@export var animation_name : StringName = &""
@export var animation_speed : float = 1.0
## 技能前摇时间（开启/关闭前的等待）
@export var pre_cast_delay : float = 0.0
## 技能后摇时间（开启/关闭后的僵直）
@export var post_cast_delay : float = 0.0
## 技能冷却时间（切换时触发冷却）
@export var cooldown_duration : float = 0.0

@export_group("Toggle Settings")
## 切换时应用的状态（开启时应用，关闭时移除）
@export var toggle_statuses : Array[GameplayStatusData] = []
## 目标获取策略（通常使用 SelfTargetingStrategy）
@export var targeting_strategy: TargetingStrategy = null
## 目标 Key
@export var target_key: String = "targets"
## 激活时的图标（当状态存在时显示的图标）
@export var icon_when_active: Texture = null

## 创建技能实例
func create_instance(owner: Node) -> GameplayAbilityInstance:
	# 0. 动态注入 ToggleFeature（如果不存在）
	var has_toggle = false
	for f in features:
		if f is ToggleFeature:
			has_toggle = true
			break
	
	if not has_toggle:
		var toggle_feature = ToggleFeature.new()
		features.append(toggle_feature)
	
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
	
	# 2. 动态注入 DynamicIconFeature（如果配置了激活图标）
	# 图标映射由 Feature 配置，行为树节点通过设置黑板变量来切换图标
	if is_instance_valid(icon_when_active):
		var has_icon_feature = false
		for f in features:
			if f is DynamicIconFeature:
				has_icon_feature = true
				# 如果已存在，更新图标映射
				var icon_feature = f as DynamicIconFeature
				if not icon_feature.icon_map.has("active"):
					icon_feature.icon_map["active"] = icon_when_active
				break
		
		if not has_icon_feature:
			var icon_feature = DynamicIconFeature.new()
			icon_feature.icon_map = {
				"active": icon_when_active  # 激活时的图标
			}
			icon_feature.icon_id_key = "current_icon_id"  # 默认的图标ID key
			features.append(icon_feature)

	# 3. 动态构建行为树（如果用户没在编辑器里手动拖树）
	if execution_tree == null:
		execution_tree = _build_default_behavior_tree()

	# 4. 调用父类创建实例
	return super(owner)

## 动态构建行为树结构
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

	# 5. 切换逻辑：使用 BTSelector 实现
	# 第一个分支：关闭（基于 toggle_action 变量）
	# 第二个分支：开启（基于 toggle_action 变量）
	# 注意：toggle_action 变量由 ToggleFeature 在 on_activate 中设置
	var toggle_selector = BTSelector.new()
	toggle_selector.node_id = "toggle_selector"
	
	# 分支1：关闭（移除状态）
	var turn_off_sequence = BTSequence.new()
	turn_off_sequence.node_id = "turn_off_sequence"
	
	# 检查黑板变量，判断是否为"关闭"操作
	var check_toggle_action_off = BTCheckVarAction.new()
	check_toggle_action_off.key = "toggle_action"
	check_toggle_action_off.value = "turn_off"
	check_toggle_action_off.node_id = "check_toggle_action_off"
	turn_off_sequence.children.append(check_toggle_action_off)
	
	# 移除状态
	var status_ids: Array[StringName] = []
	for status_data in toggle_statuses:
		if is_instance_valid(status_data) and not status_data.status_id.is_empty():
			status_ids.append(status_data.status_id)
	
	if not status_ids.is_empty():
		var remove_status_node = AbilityNodeRemoveStatus.new()
		remove_status_node.status_ids = status_ids
		remove_status_node.target_key = target_key
		remove_status_node.node_id = "remove_status"
		turn_off_sequence.children.append(remove_status_node)
	
	# 清除激活图标（恢复默认图标）
	if is_instance_valid(icon_when_active):
		var clear_icon_node = BTSetVar.new()
		clear_icon_node.variable_key = "current_icon_id"
		clear_icon_node.value = null  # null 表示恢复默认图标
		clear_icon_node.node_id = "clear_active_icon"
		turn_off_sequence.children.append(clear_icon_node)
	
	# 提交冷却（关闭时触发冷却）
	if cooldown_duration > 0.0:
		var commit_cd = AbilityNodeCommitCooldown.new()
		commit_cd.node_id = "commit_cooldown"
		turn_off_sequence.children.append(commit_cd)
	
	toggle_selector.children.append(turn_off_sequence)
	
	# 分支2：开启（应用状态）
	var turn_on_sequence = BTSequence.new()
	turn_on_sequence.node_id = "turn_on_sequence"
	
	# 检查黑板变量，判断是否为"开启"操作
	var check_toggle_action_on = BTCheckVarAction.new()
	check_toggle_action_on.key = "toggle_action"
	check_toggle_action_on.value = "turn_on"
	check_toggle_action_on.node_id = "check_toggle_action_on"
	turn_on_sequence.children.append(check_toggle_action_on)
	
	# 提交消耗（开启时消耗资源，如魔法值）
	# 注意：消耗检查在 try_activate 时已经通过 can_activate 完成
	# 这里只是实际支付消耗
	var commit_cost_node = AbilityNodeCommitCost.new()
	commit_cost_node.node_id = "commit_cost"
	turn_on_sequence.children.append(commit_cost_node)
	
	# 应用状态
	if not status_ids.is_empty():
		var apply_status_node = AbilityNodeApplyStatus.new()
		apply_status_node.statuses = toggle_statuses.duplicate()
		apply_status_node.target_key = target_key
		apply_status_node.node_id = "apply_status"
		turn_on_sequence.children.append(apply_status_node)
	
	# 设置激活图标（如果配置了）
	if is_instance_valid(icon_when_active):
		var set_icon_node = BTSetVar.new()
		set_icon_node.variable_key = "current_icon_id"
		set_icon_node.value = "active"  # 设置图标ID为 "active"
		set_icon_node.node_id = "set_active_icon"
		turn_on_sequence.children.append(set_icon_node)
	
	toggle_selector.children.append(turn_on_sequence)
	
	nodes.append(toggle_selector)
	
	# 6. 后摇等待
	if post_cast_delay > 0.0:
		var wait = BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)
	
	# 组装序列
	sequence.children = nodes
	sequence.node_id = "toggle_ability_sequence"
	return sequence
