extends ActiveAbility
class_name ChannelingAbility

## 引导/切换技能基类
## 支持两种模式：按住施法(HOLD_TO_CHANNEL) 和 切换式(TOGGLE)
##
## 设计原则：
## - 使用基类的 statuses 系统，通过 Status 的 periodic_effects 实现周期性效果
## - 引导技能自己管理生命周期，不依赖基类的 execution_duration
## - 通过 tick_costs 实现周期性消耗检查

enum ChannelingMode {
	HOLD_TO_CHANNEL, ## 按住施法：松开按键时停止
	TOGGLE           ## 切换式：再次按下按键时停止
}

@export_group("Channeling Rules")
## 引导模式
@export var channeling_mode: ChannelingMode = ChannelingMode.HOLD_TO_CHANNEL
## 最大持续时间（秒）。<= 0 表示无限持续，直到手动停止。
@export var max_duration: float = 5.0
## 周期性触发间隔（秒）。<= 0 表示不进行周期性触发。
## 注意：此间隔用于 tick_costs 检查和中断检查，实际周期性效果由 Status 的 period 控制
@export var tick_interval: float = 0.5

@export_group("Channeling Costs")
## 每次 Tick 需要支付的消耗 (资源不足将导致中断)
## 注意：周期性效果应该通过 Status 的 periodic_effects 实现，而不是 tick_statuses
@export var tick_costs: Array[AbilityCostBase] = []

@export_group("Channeling Tags")
## 引导期间给自己打上的标签（如 State.Channeling）
## 用于动画状态机切换或阻止其他技能
@export var self_channeling_tags: Array[StringName] = []
## 中断引导的标签列表
## 如果施法者拥有任意一个标签，引导会被中断
## 例如：["State.Stunned", "State.Silenced"] 表示被眩晕或沉默时中断
@export var interrupt_tags: Array[StringName] = []

@export_group("Channeling UI")
## 技能开启后显示的图标（用于提示关闭）
## 如果未设置，则使用默认图标
## 主要用于 Toggle 模式，提示玩家可以再次点击关闭
@export var icon_when_active: Texture = null

# ========== 运行时状态 ==========
var _is_active: bool = false
var _current_duration: float = 0.0
var _tick_timer: SceneTreeTimer = null
# 缓存运行时所需的数据
var _cached_ability_comp: Node = null
var _cached_instigator: Node = null

# 用于切换类技能：检查是否开启
func is_toggled_on() -> bool:
	return _is_active and channeling_mode == ChannelingMode.TOGGLE

# 用于引导类技能：检查是否需要按住
var stop_on_input_release: bool:
	get: return channeling_mode == ChannelingMode.HOLD_TO_CHANNEL

## [重写] 提交施法
## 引导技能需要接管生命周期，阻止基类启动自动执行计时器。
## 对于 Toggle 技能，如果已经开启，则执行关闭逻辑。
func _commit_cast(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 1. Toggle 模式的关闭逻辑
	if channeling_mode == ChannelingMode.TOGGLE and _is_active:
		stop_channeling("toggle_off")
		# 返回 false 表示不继续执行后续的施法逻辑（如冷却、消耗）
		# 但实际上关闭操作是成功的。这里返回 false 是为了告诉组件不要进入 _on_cast
		return false
	
	# 2. 检查是否已经激活（防止重复扣除费用）
	# 如果技能已经被激活，说明费用已经扣除过了，直接返回 true
	# 这种情况可能发生在：技能被取消后，用户继续按住按键，导致再次触发 commit_cast
	if _is_active:
		# 技能已经激活，跳过费用扣除，直接返回成功
		# 注意：这里不调用 super，因为费用已经在第一次激活时扣除了
		return true
		
	# 3. 正常开启逻辑：调用基类处理初始消耗
	# 注意：基类的 _commit_cast 会启动 _start_execution_timer()，但引导技能会自己管理生命周期
	# 所以我们需要阻止基类启动计时器，通过重写 _start_execution_timer() 来实现
	# 【关键】引导技能在开启时不进入冷却，在关闭时才开始冷却
	# 所以我们需要跳过冷却检查（通过 context 传递 skip_cooldown）
	# 注意：直接修改 context，让 GameplayAbilityComponent.commit_cast 能读取到 skip_cooldown
	context["skip_cooldown"] = true
	# 【关键】引导技能自己管理生命周期，不应该启动逻辑计时器（cast_point_timer）
	# 设置此标志，让 GameplayAbilityComponent 跳过计时器启动，直接应用效果
	context["skip_cast_point_timer"] = true
	var result = super(ability_comp, context)
	if not result:
		return false
	
	# 4. 【关键】引导技能不依赖基类的 execution_duration，生命周期由自己管理
	# 基类已经启动了 _start_execution_timer()，但我们在 _start_execution_timer() 中会阻止它
	return true

## [重写] 施法开始
## 引导技能自己管理生命周期，不依赖基类的执行计时器
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ChannelingAbility: Cannot cast, instigator is not valid")
		return
	
	# 1. 应用直接效果（简单效果，立即执行）
	# 注意：使用基类的 _apply_initial_effects() 方法，支持瞬时效果
	_apply_initial_effects(instigator, input_target, context)
	
	# 2. 应用初始状态（如前摇效果），复用基类的状态应用逻辑
	# 注意：使用基类的 _apply_initial_statuses() 方法，而不是 super._on_cast()
	# 因为 super._on_cast() 会启动执行计时器，但引导技能自己管理生命周期
	_apply_initial_statuses(instigator, input_target, context)
	
	# 3. 缓存数据
	_cached_ability_comp = ability_comp
	_cached_instigator = instigator

	# 4. 启动引导/切换核心逻辑
	_start_channeling(instigator)

## [重写] 启动执行计时器
## 引导技能不依赖基类的 execution_duration，生命周期由自己管理
## 所以重写此方法，阻止基类启动计时器
func _start_execution_timer(ability_comp: Node) -> void:
	# 引导技能自己管理生命周期，不启动基类的执行计时器
	pass

## [重写] 获取技能图标
## 当技能开启时，返回 icon_when_active（如果已设置），否则返回默认图标
func _get_icon() -> Texture:
	if _is_active and is_instance_valid(icon_when_active):
		return icon_when_active
	return super()

# ========== 引导核心逻辑 ==========

func _start_channeling(instigator: Node) -> void:
	if _is_active: return # 防止重复启动
	
	_is_active = true
	_current_duration = 0.0
	
	# 1. 给自己打上引导标签
	if not self_channeling_tags.is_empty():
		TagManager.add_tags(instigator, self_channeling_tags)
	
	# 2. 启动 Tick 循环
	_schedule_next_tick()
	
	# 3. 对于 Toggle 技能，需要立即通知组件技能"完成"，以便释放 _current_casting_ability_id
	# 这样玩家就可以施放其他技能了。引导技能则保持占用状态。
	if channeling_mode == ChannelingMode.TOGGLE:
		# 这是一个特殊的处理：我们手动触发一次 completed 信号
		# 组件收到后会调用 _end_ability 并清理 _current_casting_ability_id
		ability_completed.emit(self)

	print("ChannelingAbility: Started %s (mode: %s)" % [ability_id, ChannelingMode.keys()[channeling_mode]])

## 停止引导（统一入口）
func stop_channeling(reason: String = "manual") -> void:
	if not _is_active: 
		return
	
	_is_active = false
	
	# 1. 清理计时器
	if is_instance_valid(_tick_timer):
		_tick_timer.timeout.disconnect(_process_tick)
		_tick_timer = null
		
	# 2. 移除引导标签
	if is_instance_valid(_cached_instigator) and not self_channeling_tags.is_empty():
		TagManager.remove_tags(_cached_instigator, self_channeling_tags)
	
	# 3. 移除由该技能应用的所有状态
	if is_instance_valid(_cached_instigator) and is_instance_valid(_cached_ability_comp):
		var status_comp = GameplayAbilitySystem.get_component_by_interface(_cached_instigator, "GameplayStatusComponent")
		if is_instance_valid(status_comp):
			# 遍历技能配置的所有状态，移除它们
			for status_data in statuses:
				if not is_instance_valid(status_data):
					continue
				# 通过状态ID移除状态
				status_comp.remove_status(status_data.status_id)
	
	# 4. 开始冷却时间（引导技能在关闭时才开始冷却）
	var cooldown = get_cooldown_duration()
	if cooldown > 0.0:
		start_cooldown(cooldown)
	
	# 5. 清理缓存
	_cached_ability_comp = null
	_cached_instigator = null
			
	print("ChannelingAbility: Stopped %s. Reason: %s" % [ability_id, reason])
	
	# 6. 【关键】通知 AbilityComponent 技能结束
	# 对于 Toggle 技能，这会触发冷却计算（如果配置了冷却）
	# 对于引导技能，这会释放 _current_casting_ability_id 并触发冷却
	_check_ability_completion()

## 安排下一次 Tick
func _schedule_next_tick() -> void:
	if not _is_active or tick_interval <= 0.0: return
	
	var scene_tree = _cached_ability_comp.get_tree()
	if not is_instance_valid(scene_tree): return
	
	# 使用 SceneTreeTimer 创建递归循环
	_tick_timer = scene_tree.create_timer(tick_interval)
	_tick_timer.timeout.connect(_process_tick)

## Tick 处理逻辑
## 注意：周期性效果由 Status 的 periodic_effects 处理，此方法只负责：
## 1. 持续时间检查
## 2. 中断检查
## 3. Tick 消耗检查
func _process_tick() -> void:
	if not _is_active: 
		return
	
	if not is_instance_valid(_cached_instigator) or not is_instance_valid(_cached_ability_comp):
		stop_channeling("instigator_invalid")
		return
		
	# 1. 检查最大持续时间
	_current_duration += tick_interval
	if max_duration > 0.0 and _current_duration >= max_duration:
		stop_channeling("duration_expired")
		return
		
	# 2. 被动中断检查（Tag 系统）
	# 如果配置了中断标签，检查施法者是否拥有任意一个标签
	if not interrupt_tags.is_empty():
		if TagManager.has_any_tag(_cached_instigator, interrupt_tags):
			stop_channeling("interrupted")
			return

	# 3. 尝试支付 Tick 消耗（资源不足将导致中断）
	if not _pay_tick_costs():
		stop_channeling("out_of_resource")
		return
	
	# 4. 继续循环
	# 注意：周期性效果由 Status 的 periodic_effects 处理，不需要在这里手动应用
	_schedule_next_tick()

## 支付 Tick 消耗
func _pay_tick_costs() -> bool:
	if tick_costs.is_empty(): 
		return true
	
	if not is_instance_valid(_cached_ability_comp) or not is_instance_valid(_cached_instigator):
		return false
	
	# 先检查是否都付得起
	for cost in tick_costs:
		if not is_instance_valid(cost):
			continue
		if not cost.can_pay(_cached_ability_comp, _cached_instigator):
			return false
			
	# 再实际支付
	for cost in tick_costs:
		if is_instance_valid(cost):
			cost.try_pay(_cached_ability_comp, _cached_instigator)
		
	return true

func _on_cancel(_ability_comp: Node, _context: Dictionary = {}) -> void:
	# 如果技能已经激活，停止引导
	# 注意：这里调用 stop_channeling 会清除 _is_active，但不会清除 _current_casting_ability_id
	# 这样可以防止用户继续按住时重复扣除费用
	if _is_active:
		stop_channeling("cancelled")
