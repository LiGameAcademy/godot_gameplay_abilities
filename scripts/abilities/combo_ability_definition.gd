extends GameplayAbilityDefinition
class_name ComboAbilityDefinition

@export_group("Combo Config")
@export var combo_steps: Array[ActiveAbilityDefinition] = []
@export var window_duration: float = 0.8
@export var costs : Array[AbilityCostBase] = []
@export var cooldown_duration: float = 0.0
@export var cost_feature_name: String = "CostFeature"
@export var cooldown_feature_name: String = "CooldownFeature"

# ========== 行为树缓存（享元模式） ==========
## 缓存的默认行为树（所有实例共享，避免重复构建）
## 只在第一次创建实例时构建，之后所有实例共享
var _cached_combo_tree: BTNode = null

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
	
	# 6. 初始化黑板变量
	_initialize_blackboard(instance)
	
	# 7. 在 Instance 中动态注入 Feature（不修改 Definition，避免资源污染）
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
	if is_instance_valid(_cached_combo_tree):
		return _cached_combo_tree
	
	# 构建并缓存（只构建一次，之后所有实例共享）
	_cached_combo_tree = _build_combo_tree()
	return _cached_combo_tree

## 在 Instance 中注入 Feature（不修改 Definition，避免资源污染）
## [param] instance: GameplayAbilityInstance 技能实例
func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
	# 注入 CostFeature（如果配置了消耗且不存在）
	if not costs.is_empty():
		if not _has_feature(instance, CostFeature):
			var cost_feature = CostFeature.new()
			cost_feature.costs = costs
			cost_feature.feature_name = cost_feature_name
			instance.add_feature(cost_feature.feature_name, cost_feature)
	
	# 注入 CooldownFeature（如果配置了冷却时间且不存在）
	if cooldown_duration > 0.0:
		if not _has_feature(instance, CooldownFeature):
			var cooldown_feature = CooldownFeature.new()
			cooldown_feature.cooldown_duration = cooldown_duration
			cooldown_feature.feature_name = cooldown_feature_name
			instance.add_feature(cooldown_feature.feature_name, cooldown_feature)
	
	# 注入 DynamicIconFeature（如果连击段有图标）
	_inject_icon_feature(instance)

## 注入图标 Feature
## [param] instance: GameplayAbilityInstance 技能实例
func _inject_icon_feature(instance: GameplayAbilityInstance) -> void:
	var icon_map: Dictionary = {}
	
	# 收集所有连击段的图标
	for i in range(combo_steps.size()):
		var step_def = combo_steps[i]
		if is_instance_valid(step_def) and is_instance_valid(step_def.icon):
			icon_map["combo_%d" % (i + 1)] = step_def.icon
	
	# 如果至少有一个图标，则注入 Feature
	if not icon_map.is_empty():
		# 检查是否已存在 DynamicIconFeature
		var existing_feature = _get_feature(instance, DynamicIconFeature)
		if is_instance_valid(existing_feature):
			# 如果已存在，移除旧的并创建新的（确保使用最新的图标映射）
			instance.remove_feature(existing_feature.feature_name)
		
		# 创建新的 Feature
		var icon_feature = DynamicIconFeature.new()
		icon_feature.icon_map = icon_map.duplicate()
		icon_feature.icon_id_key = "current_icon_id"
		instance.add_feature(icon_feature.feature_name, icon_feature)

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

## 获取指定类型的 Feature
## [param] instance: GameplayAbilityInstance 技能实例
## [param] feature_type: GDScript Feature 类型
## [return] GameplayAbilityFeature Feature 实例，如果不存在则返回 null
func _get_feature(instance: GameplayAbilityInstance, feature_type: GDScript) -> GameplayAbilityFeature:
	var all_features = instance.get_features()
	for feature in all_features:
		if feature.get_script() == feature_type:
			return feature
	return null

## 初始化黑板变量
## [param] instance: GameplayAbilityInstance 技能实例
func _initialize_blackboard(instance: GameplayAbilityInstance) -> void:
	instance.set_blackboard_var("combo_index", 0)
	instance.set_blackboard_var("combo_expiry_time", 0)
	instance.set_blackboard_var("combo_next_icon", null) # 初始为空，UI应显示默认图标

## 验证配置的合理性
func _validate_configuration() -> void:
	# 验证：连击段不能为空
	if combo_steps.is_empty():
		push_error("ComboAbilityDefinition [%s]: combo_steps 不能为空" % ability_id)
		return
	
	# 验证：连击窗口期应该为正数
	if window_duration <= 0.0:
		push_error("ComboAbilityDefinition [%s]: window_duration 必须为正数 (%.2f)" % [ability_id, window_duration])
		window_duration = 0.8  # 使用默认值
	
	# 验证：冷却时间应该非负
	if cooldown_duration < 0.0:
		push_error("ComboAbilityDefinition [%s]: cooldown_duration 不能为负数 (%.2f)" % [ability_id, cooldown_duration])
		cooldown_duration = 0.0
	
	# 验证：连击段的有效性
	for i in range(combo_steps.size()):
		var step = combo_steps[i]
		if not is_instance_valid(step):
			push_warning("ComboAbilityDefinition [%s]: combo_steps[%d] 无效" % [ability_id, i])

func _build_combo_tree() -> BTNode:
	# --- 最外层 Sequence ---
	# 结构: [Cost -> RepeatUntilFailure(Switch) -> Cooldown]
	var root_sequence = BTSequence.new()
	
	# 1. 【头部】应用消耗 (无论第几段，只要触发技能就检查消耗)
	# 如果你想只在第一段消耗，可以在 Switch 内部的第一段里加 Cost
	# 但根据你的描述"连击开始时产生消耗"，通常放在这里比较稳妥（或者依赖 CostFeature 自身的逻辑）
	var cost_node = AbilityNodeCommitCost.new()
	cost_node.node_id = "commit_cost"
	root_sequence.children.append(cost_node)
	
	# 2. 【中部】RepeatUntilFailure 包裹 Switch 选择器
	# 逻辑：循环执行连击段，直到某一段超时失败（BTWaitSignal 返回 FAILURE）
	var repeat_node = BTRepeatUntilFailure.new()
	repeat_node.node_id = "combo_loop"
	
	var switch_node = BTSwitch.new()
	switch_node.variable_key = "combo_index"
	switch_node.node_id = "combo_switch"
	# 注意：BTSwitch 只负责根据索引选择子节点，不处理超时逻辑
	# 超时由连击段内部的 BTWaitSignal 返回 FAILURE 来处理
	var switch_children: Array[BTNode] = []
	 
	for i in range(combo_steps.size()):
		var step_def = combo_steps[i]
		var is_last_step = (i == combo_steps.size() - 1)
		
		# 构建子树包装器
		var wrapper = BTSequence.new()
		wrapper.node_id = "combo_step_%d" % (i + 1)
		
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
			if duplicated_tree.node_id.is_empty():
				duplicated_tree.node_id = "step_%d_execution_tree" % (i + 1)
			wrapper.children.append(duplicated_tree)
		
		# B. 【关键】添加 BTWaitSignal 等待连击输入
		# 这是连击系统的核心：等待玩家在窗口期内输入，或超时失败
		var wait_signal = BTWaitSignal.new()
		wait_signal.signal_key = "event_input_received"
		wait_signal.timeout = window_duration  # 使用连击窗口期作为超时时间
		wait_signal.consume_signal = true  # 消费信号，避免重复触发
		wait_signal.node_id = "wait_combo_input"
		wrapper.children.append(wait_signal)
		
		# C. 推进索引（使用 BTModifyInt 或 AbilityNodeAdvanceCombo）
		# 注意：只有在 BTWaitSignal 返回 SUCCESS（收到输入）时才会执行到这里
		# 如果 BTWaitSignal 返回 FAILURE（超时），整个 wrapper 会返回 FAILURE
		var advance_node = AbilityNodeAdvanceCombo.new()
		advance_node.reset_timer = window_duration
		advance_node.is_finisher = is_last_step
		advance_node.node_id = "advance_combo"
		wrapper.children.append(advance_node)
		
		# D. 设置下一段的图标ID
		var icon_node = BTSetVar.new()
		icon_node.variable_key = "current_icon_id"
		if is_last_step:
			# 如果是终结技，下一段图标重置为第一段的图标，形成闭环
			icon_node.value = "combo_1" if combo_steps.size() > 0 else null
		else:
			# 如果是中间段，设置为下一段的图标ID
			# 比如当前是 i，打完后 UI 应该显示 i+1 的样子
			if i + 1 < combo_steps.size():
				icon_node.value = "combo_%d" % (i + 2)  # i+1 对应 combo_i+2（因为从1开始）
			else:
				icon_node.value = null
		icon_node.node_id = "set_combo_icon"
		wrapper.children.append(icon_node)
		
		switch_children.append(wrapper)
	
	switch_node.children = switch_children
	repeat_node.child = switch_node  # 使用 child 属性（Decorator 模式）
	root_sequence.children.append(repeat_node)
	
	# 3. 【尾部】应用冷却
	# 当 RepeatUntilFailure 返回 FAILURE（某一段超时）时，执行 CD 并完成技能
	var cd_node = AbilityNodeCommitCooldown.new()
	cd_node.node_id = "commit_cooldown"
	root_sequence.children.append(cd_node)
	
	# 为根序列设置名称
	root_sequence.node_id = "combo_root_sequence"
	
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
