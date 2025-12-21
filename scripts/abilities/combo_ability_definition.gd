extends GameplayAbilityDefinition
class_name ComboAbilityDefinition

@export_group("Combo Config")
@export var combo_steps: Array[ActiveAbilityDefinition] = []
@export var window_duration: float = 0.8
@export var costs : Array[AbilityCostBase] = []
@export var cooldown_duration: float = 0.0
@export var cost_feature_name: String = "CostFeature"
@export var cooldown_feature_name: String = "CooldownFeature"

# 重写创建实例
func create_instance(owner: Node) -> GameplayAbilityInstance:
	if execution_tree == null:
		execution_tree = _build_combo_tree()
		
	# 注入 Cost 和 Cooldown 特性的逻辑
	var cost_feature = CostFeature.new()
	cost_feature.costs = costs
	cost_feature.feature_name = cost_feature_name
	features.append(cost_feature)
	
	var cooldown_feature = CooldownFeature.new()
	cooldown_feature.cooldown_duration = cooldown_duration
	cooldown_feature.feature_name = cooldown_feature_name
	features.append(cooldown_feature)
	
	var instance = super.create_instance(owner)
	
	# 初始化黑板
	instance.set_blackboard_var("combo_index", 0)
	instance.set_blackboard_var("combo_expiry_time", 0)
	instance.set_blackboard_var("combo_next_icon", null) # 初始为空，UI应显示默认图标
	
	return instance

func _build_combo_tree() -> BTNode:
	# --- 最外层 Sequence ---
	# 结构: [Cost -> RepeatUntilFailure(Switch) -> Cooldown]
	var root_sequence = BTSequence.new()
	
	# 1. 【头部】应用消耗 (无论第几段，只要触发技能就检查消耗)
	# 如果你想只在第一段消耗，可以在 Switch 内部的第一段里加 Cost
	# 但根据你的描述"连击开始时产生消耗"，通常放在这里比较稳妥（或者依赖 CostFeature 自身的逻辑）
	var cost_node = AbilityNodeCommitCost.new()
	cost_node.node_name = "应用消耗"
	root_sequence.children.append(cost_node)
	
	# 2. 【中部】RepeatUntilFailure 包裹 Switch 选择器
	# 逻辑：循环执行连击段，直到某一段超时失败（BTWaitSignal 返回 FAILURE）
	var repeat_node = BTRepeatUntilFailure.new()
	repeat_node.node_name = "连击循环"
	
	var switch_node = BTSwitch.new()
	switch_node.variable_key = "combo_index"
	switch_node.node_name = "连击选择器"
	# 注意：BTSwitch 只负责根据索引选择子节点，不处理超时逻辑
	# 超时由连击段内部的 BTWaitSignal 返回 FAILURE 来处理
	var switch_children: Array[BTNode] = []
	 
	for i in range(combo_steps.size()):
		var step_def = combo_steps[i]
		var is_last_step = (i == combo_steps.size() - 1)
		
		# 构建子树包装器
		var wrapper = BTSequence.new()
		wrapper.node_name = "连击段 %d" % (i + 1)
		
		# A. 执行段的能力树（包含前摇、打击、后摇等）
		# 注意：连击段不应该包含CD，CD只在连击整体结束时应用
		var step_tree = step_def.execution_tree
		if step_tree == null and step_def.has_method("_build_default_behavior_tree"):
			# 构建不带CD的行为树（连击段不需要单独的CD）
			step_tree = step_def.call("_build_default_behavior_tree", false)
		if step_tree:
			# 为段树设置名称
			var duplicated_tree = step_tree.duplicate(true)
			# 移除可能存在的CD节点（如果用户手动配置了execution_tree）
			_remove_cooldown_nodes(duplicated_tree)
			if duplicated_tree.node_name.is_empty():
				duplicated_tree.node_name = "段 %d 执行树" % (i + 1)
			wrapper.children.append(duplicated_tree)
		
		# B. 【关键】添加 BTWaitSignal 等待连击输入
		# 这是连击系统的核心：等待玩家在窗口期内输入，或超时失败
		var wait_signal = BTWaitSignal.new()
		wait_signal.signal_key = "event_input_received"
		wait_signal.timeout = window_duration  # 使用连击窗口期作为超时时间
		wait_signal.consume_signal = true  # 消费信号，避免重复触发
		wait_signal.node_name = "等待连击输入"
		wrapper.children.append(wait_signal)
		
		# C. 推进索引（使用 BTModifyInt 或 AbilityNodeAdvanceCombo）
		# 注意：只有在 BTWaitSignal 返回 SUCCESS（收到输入）时才会执行到这里
		# 如果 BTWaitSignal 返回 FAILURE（超时），整个 wrapper 会返回 FAILURE
		var advance_node = AbilityNodeAdvanceCombo.new()
		advance_node.reset_timer = window_duration
		advance_node.is_finisher = is_last_step
		advance_node.node_name = "推进连击索引"
		wrapper.children.append(advance_node)
		
		# D. 设置下一段的图标
		var icon_node = AbilityNodeSetComboIcon.new()
		if is_last_step:
			# 如果是终结技，下一段图标重置为第一段的图标 (或 Ability 自身的默认图标)
			# 这里我们设置为第一段的图标，形成闭环
			icon_node.icon_texture = combo_steps[0].icon if combo_steps.size() > 0 else null
		else:
			# 如果是中间段，设置为下一段的图标
			# 比如当前是 i，打完后 UI 应该显示 i+1 的样子
			if i + 1 < combo_steps.size():
				icon_node.icon_texture = combo_steps[i+1].icon
		icon_node.node_name = "更新连击图标"
		wrapper.children.append(icon_node)
		
		switch_children.append(wrapper)
	
	switch_node.children = switch_children
	repeat_node.child = switch_node  # 使用 child 属性（Decorator 模式）
	root_sequence.children.append(repeat_node)
	
	# 3. 【尾部】应用冷却
	# 当 RepeatUntilFailure 返回 FAILURE（某一段超时）时，执行 CD 并完成技能
	var cd_node = AbilityNodeCommitCooldown.new()
	cd_node.node_name = "应用冷却"
	root_sequence.children.append(cd_node)
	
	# 为根序列设置名称
	root_sequence.node_name = "连击根序列"
	
	return root_sequence

## 递归移除行为树中的冷却节点（用于连击段）
func _remove_cooldown_nodes(node: BTNode) -> void:
	if not is_instance_valid(node):
		return
	
	# 如果是组合节点，递归处理子节点
	if node is BTComposite:
		var composite = node as BTComposite
		# 从后往前遍历，避免删除时索引问题
		for i in range(composite.children.size() - 1, -1, -1):
			var child = composite.children[i]
			if child is AbilityNodeCommitCooldown:
				# 移除CD节点
				composite.children.remove_at(i)
			else:
				# 递归处理子节点
				_remove_cooldown_nodes(child)
	elif node is BTDecorator:
		var decorator = node as BTDecorator
		if is_instance_valid(decorator.child):
			if decorator.child is AbilityNodeCommitCooldown:
				# 如果装饰器的子节点是CD节点，移除它（这通常不会发生，但为了安全）
				decorator.child = null
			else:
				_remove_cooldown_nodes(decorator.child)
