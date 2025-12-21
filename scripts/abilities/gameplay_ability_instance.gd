extends RefCounted
class_name GameplayAbilityInstance

## 技能数据基类
## 定义技能的所有属性和行为

var _owner: Node
var _definition: GameplayAbilityDefinition
var _features: Dictionary[String, GameplayAbilityFeature] = {}
var _bt_instance : BTInstance = null
var _blackboard: BTBlackboard = null

# 【核心状态】技能是否正在执行（行为树是否在跑）
var is_active: bool = false
var disabled : bool = false:
	get:
		return _definition.disabled

## 技能完成信号
## Component 会订阅此信号来判断技能是否完成
signal ability_completed(ability: GameplayAbilityInstance)
## 技能数据改变
signal ability_data_changed(ability: GameplayAbilityInstance)

func _init(owner: Node, definition: GameplayAbilityDefinition) -> void:
	_owner = owner
	_definition = definition
	# 初始化行为树黑板
	_blackboard = BTBlackboard.new()
	_blackboard.value_changed.connect(_on_blackboard_value_changed)
	_blackboard.set_var("ability_instance", self)
	if is_instance_valid(_definition.execution_tree):
		_bt_instance = BTInstance.new(_owner, _definition.execution_tree, _blackboard)

#region ========== 特性管理 ==========

## 添加特性
func add_feature(feature_name: String, feature: GameplayAbilityFeature) -> void:
	if _features.has(feature_name):
		push_warning("Feature already exists: ", feature_name)
		return
	_features[feature_name] = feature
	feature.initialize(self)

## 移除特性
func remove_feature(feature_name: String) -> void:
	if not _features.has(feature_name):
		push_warning("Feature not found: ", feature_name)
		return
	_features.erase(feature_name)

## 获取特性
func get_feature(feature_name: String) -> GameplayAbilityFeature:
	if not _features.has(feature_name):
		return null
	return _features[feature_name]

## 是否存在特性
func has_feature(feature_name: String) -> bool:
	return _features.has(feature_name)

## 获取所有特性
func get_all_features() -> Dictionary[String, GameplayAbilityFeature]:
	return _features

## 获取特性数量
func get_feature_count() -> int:
	return _features.size()

## 获取特性名称列表
func get_feature_names() -> Array[String]:
	return _features.keys()

## 获取特性列表
func get_features() -> Array[GameplayAbilityFeature]:
	return _features.values()

#endregion

#region ========== 行为树管理 ==========
## 获取行为树实例
func get_bt_instance() -> BTInstance:
	return _bt_instance

func get_blackboard() -> BTBlackboard:
	return _blackboard

func set_blackboard_var(key: String, value: Variant) -> void:
	_blackboard.set_var(key, value)

func get_blackboard_var(key: String, default: Variant = null) -> Variant:
	return _blackboard.get_var(key, default)

func clear_blackboard() -> void:
	_blackboard.clear()
#endregion

#region ========== 技能生命周期管理 ==========
## 处理技能学习事件
## 当技能被学习时，由 GameplayAbilityComponent 调用此方法
func handle_learned(ability_comp: Node, status_comp: Node) -> void:
	# 调用所有特性的 on_learned（被动技能钩子）
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.on_learned(self, ability_comp, status_comp)

## 处理技能遗忘事件
## 当技能被遗忘时，由 GameplayAbilityComponent 调用此方法
func handle_forgotten(ability_comp: Node, status_comp: Node) -> void:
	# 调用所有特性的 on_forgotten（被动技能钩子）
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.on_forgotten(self, ability_comp, status_comp)

## 尝试激活技能 (由 Player/Component 调用)
func try_activate(context: Variant = {}) -> bool:
	if is_active:
		# 如果已经在跑了，通常拒绝（除非是连击技能，连击有特殊逻辑）
		# 注意：即使值已经是 true，也要确保触发信号（通过先设置为 false 再设置为 true）
		# 这样可以确保 BTWaitSignal 能够收到通知，即使它刚刚消费了信号
		var current_value = _blackboard.get_var("event_input_received", false)
		if not current_value:
			_blackboard.set_var("event_input_received", true)
		else:
			# 如果已经是 true，先设置为 false 再设置为 true，确保触发信号
			_blackboard.set_var("event_input_received", false)
			_blackboard.set_var("event_input_received", true)
		return true

	var ctx = ContextUtils.to_context(context)
	
	# 1. 检查能不能放 (Cost, CD, Tags, Features)
	if not can_activate(ctx):
		return false

	# 2. 【关键】启动行为树
	# 注意：这里我们只"启动"状态，不扣蓝，也不产生效果。
	# 扣蓝和效果由树里面的节点决定何时发生。
	is_active = true
	
	# 3. 注入初始黑板数据
	if is_instance_valid(_blackboard):
		_blackboard.clear() # 清理上一轮的残留
		# 将 context 注入黑板，供树节点读取
		_blackboard.set_var("ability_instance", self)
		_blackboard.set_var("context", ctx)
		_blackboard.set_var("target", ctx.input_target)

	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.on_activate(self, ctx)
	
	return true

## [子类可重写] 每帧更新（用于需要持续更新的技能，如连击计时器、引导技能）
## [param] delta: float 帧时间
func update(delta: float) -> void:
	# 调用所有特性的 update（通用钩子，对所有技能类型有效）
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.update(self, delta)

	# 更新行为树
	if is_active and is_instance_valid(_bt_instance):
		var result = _bt_instance.tick(delta)
		if result != BTNode.Status.RUNNING:
			end_ability(result)

## 结束技能
func end_ability(final_status: int = BTNode.Status.SUCCESS) -> void:
	if not is_active: return
	
	is_active = false
	
	# 通知特性技能结束了
	for feature in _features.values():
		if is_instance_valid(feature): 
			feature.on_completed(self)
			
	# 发出信号
	ability_completed.emit(self)
	
	# (可选) 如果树还在跑但被强制结束，重置树
	if is_instance_valid(_bt_instance):
		_bt_instance.reset_tree()

## [子类可重写] 技能被取消时的处理
## 当技能被主动取消时（如被打断、资源不足等），由 GameplayAbilityComponent 调用此方法
## [param] ability_comp: Node 技能组件
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func handle_cancel(ability_comp: Node, context: Variant = {}) -> void:
	var ctx = ContextUtils.to_context(context)
	# 调用所有特性的 on_cancel（主动技能钩子）
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.on_cancel(self, context)

#endregion

#region ========== 技能查询API ==========

## 获取效果描述
func get_effects_description() -> String:
	var desc: Array[String] = []
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		desc.append(feature.get_effects_description())
	return "\n".join(desc)

## 获取动画名称（优先从特性中获取）
## [return] StringName 动画名称，如果未配置则返回空字符串
func get_animation_name() -> StringName:
	# 遍历特性，查找提供动画名称的特性（如 ActiveFeature）
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		var anim_name = feature.get_animation_name()
		if not anim_name.is_empty():
			return anim_name
	return &""

func get_definition() -> GameplayAbilityDefinition:
	return _definition

## 检查是否可以施法
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func can_activate(context: Variant = {}) -> bool:
	var ctx = ContextUtils.to_context(context)
	# 调用所有特性的 can_activate（主动技能钩子）
	# 所有特性的 can_activate 都必须返回 true
	for feature : GameplayAbilityFeature in _features.values():
		if not is_instance_valid(feature):
			continue
		if not feature.can_activate(self, ctx):
			return false
	return true

#endregion

func play_animation(animation_name: StringName, speed: float = 1.0) -> float:
	if not is_instance_valid(_owner):
		push_warning("GameplayAbilityInstance: Owner is not valid")
		return 0.0
	if not _owner.has_method("play_animation"):
		push_warning("GameplayAbilityInstance: Owner does not have play_animation method")
		return 0.0
	var result = _owner.call("play_animation", animation_name, speed)
	if result is float:
		return result
	return 0.0

func get_current_icon() -> Texture:
	# 优先从黑板读取连击图标（如果存在）
	if is_instance_valid(_blackboard):
		var combo_icon = _blackboard.get_var("combo_next_icon")
		if combo_icon is Texture:
			return combo_icon as Texture
	
	# 回退到 Definition 的默认图标
	return _definition.icon

func _on_blackboard_value_changed(key: String, value: Variant) -> void:
	ability_data_changed.emit(self)
