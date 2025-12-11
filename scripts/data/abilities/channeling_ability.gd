extends ToggleAbility
class_name ChannelingAbility

## 引导类技能（持续施法，周期触发）
## 设计目标：
## - 支持持续时间 / 周期 Tick / 完成效果
## - 支持每 Tick 消耗、结束消耗跳过（由 context 控制）
## - 可配置是否允许移动、按键松开是否中断
## - 使用 AbilityComponent 的阻塞任务，保证技能生命周期完整
## - 使用 Timer 实现逻辑，在 update() 中检查中断条件

const TAG_CHANNELING: StringName = &"state.casting.channeling"

@export_group("Channeling Settings")
@export var channel_duration: float = 0.0                   ## 引导持续时间
@export var tick_interval: float = 0.5                      ## 周期触发间隔（秒，<=0 则不触发 Tick）
@export var costs_per_tick: Array[AbilityCostBase] = []     ## 每 Tick 的资源消耗
@export var tick_effects: Array[GameplayEffect] = []        ## 每 Tick 作用于目标的效果
@export var completion_effects: Array[GameplayEffect] = []  ## 完成引导时触发的效果
@export var is_mobile: bool = false                         ## 是否允许移动引导（false 时移动视为打断）
@export var stop_on_input_release: bool = true              ## 是否按住维持（true 时松开输入即打断，false 时为切换式引导）

## 引导状态（运行时数据）
var _channeling_state: Dictionary = {}  ## 存储引导状态：ability_comp, instigator, input_target, context, input_action, tick_timer, duration_timer, is_active

## 施放入口（使用 Timer 实现引导逻辑）
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ChannelingAbility: Cannot cast, instigator is not valid")
		return
	
	# 如果已经在引导，先取消之前的引导
	if _channeling_state.get("is_active", false):
		_interrupt_channeling(ability_comp, false)
	
	# 记录输入动作，供"按住维持"模式检测
	var input_action: String = context.get("input_action", "")
	
	# 打上引导标签（如需与状态系统交互，可在外部根据 TAG_CHANNELING 处理）
	context["channeling"] = true
	
	# 应用施法者效果（包括持续特效 Cue）
	_apply_caster_effects(instigator, context)
	
	# 存储引导状态
	_channeling_state = {
		"ability_comp": ability_comp,
		"instigator": instigator,
		"input_target": input_target,
		"context": context,
		"input_action": input_action,
		"tick_timer": null,
		"duration_timer": null,
		"is_active": true
	}
	
	# 创建 Tick Timer（如果设置了 tick_interval）
	if tick_interval > 0.0:
		var tick_timer = Timer.new()
		tick_timer.name = "ChannelingTickTimer_%s" % ability_id
		tick_timer.wait_time = tick_interval
		tick_timer.one_shot = false
		tick_timer.timeout.connect(_on_tick_timeout)
		ability_comp.add_child(tick_timer)
		tick_timer.start()
		_channeling_state["tick_timer"] = tick_timer
	
	# 创建 Duration Timer
	if channel_duration > 0.0:
		var duration_timer = Timer.new()
		duration_timer.name = "ChannelingDurationTimer_%s" % ability_id
		duration_timer.wait_time = channel_duration
		duration_timer.one_shot = true
		duration_timer.timeout.connect(_on_duration_timeout)
		ability_comp.add_child(duration_timer)
		duration_timer.start()
		_channeling_state["duration_timer"] = duration_timer

## 每帧更新（检查中断条件）
func update(delta: float) -> void:
	if not _channeling_state.get("is_active", false):
		return
	
	var ability_comp = _channeling_state.get("ability_comp", null)
	var instigator = _channeling_state.get("instigator", null)
	var input_action: String = _channeling_state.get("input_action", "")
	
	# 有效性检查
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		_interrupt_channeling(ability_comp, false)
		return
	
	# 中断条件：按键松开（仅支持 Input Action，快捷键由外部处理）
	if stop_on_input_release and input_action != "" and not Input.is_action_pressed(input_action):
		_interrupt_channeling(ability_comp, false)
		return
	
	# 中断条件：不允许移动且角色在移动（需角色实现 is_moving）
	if not is_mobile and instigator.has_method("is_moving") and instigator.is_moving():
		_interrupt_channeling(ability_comp, false)
		return

## 中断引导（内部方法）
## [param] ability_comp: Node 技能组件（可选，如果不提供则从状态中获取）
## [param] completed: bool 是否正常完成（true 表示完成，false 表示中断）
func _interrupt_channeling(ability_comp: Node = null, completed: bool = false) -> void:
	if not _channeling_state.get("is_active", false):
		return
	
	_channeling_state["is_active"] = false
	
	# 从状态中获取 ability_comp（如果参数未提供）
	if not is_instance_valid(ability_comp):
		ability_comp = _channeling_state.get("ability_comp", null)
	
	# 清理 Timer
	var tick_timer = _channeling_state.get("tick_timer", null)
	if is_instance_valid(tick_timer):
		tick_timer.queue_free()
	
	var duration_timer = _channeling_state.get("duration_timer", null)
	if is_instance_valid(duration_timer):
		duration_timer.queue_free()
	
	# 通知技能完成（引导结束时）
	if is_instance_valid(ability_comp):
		ability_completed.emit(self)
	
	# 停止施法者效果的 Cue（清理持续特效）
	var instigator = _channeling_state.get("instigator", null)
	if is_instance_valid(instigator):
		for effect in caster_effects:
			if is_instance_valid(effect) and is_instance_valid(effect.cue):
				effect._stop_cue(instigator)
	
	# 清空状态
	_channeling_state.clear()

## 执行一次 Tick（支付周期消耗并应用 Tick 效果）
## 返回：是否继续引导
func _perform_tick(ability_comp: Node, instigator: Node, input_target: Node, context: Dictionary) -> bool:
	# 支付周期消耗
	for cost in costs_per_tick:
		if not is_instance_valid(cost):
			continue
		if not cost.can_pay(ability_comp, instigator):
			push_warning("ChannelingAbility: Tick cost cannot be paid for ability %s" % ability_id)
			return false
		if not cost.try_pay(ability_comp, instigator):
			push_warning("ChannelingAbility: Tick cost pay failed for ability %s" % ability_id)
			return false
	
	# 应用 Tick 效果（会自动订阅阻塞 Effect）
	if not tick_effects.is_empty():
		var targets = _resolve_targets(instigator, input_target, context)
		_apply_effects_to_targets(tick_effects, instigator, targets, context)
	
	return true

## 重写：检查技能是否处于开启状态
func is_toggled_on(ability_comp: Node) -> bool:
	return _channeling_state.get("is_active", false)

## 重写：检查是否可以关闭技能
## 切换式引导（stop_on_input_release = false）可以主动关闭
## 按住维持式引导（stop_on_input_release = true）只能被动关闭（松开按键）
func can_toggle_off(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 只有切换式引导（stop_on_input_release = false）可以主动关闭
	return not stop_on_input_release

## 重写：关闭技能
func _toggle_off(ability_comp: Node, context: Dictionary = {}) -> void:
	# 调用父类方法（会触发 cancel_ability）
	super(ability_comp, context)


## 技能被取消时的处理
func _on_cancel(ability_comp: Node, context: Dictionary = {}) -> void:
	_interrupt_channeling(ability_comp, false)

## Tick Timer 回调
func _on_tick_timeout() -> void:
	if not _channeling_state.get("is_active", false):
		return
	
	var ability_comp = _channeling_state.get("ability_comp", null)
	var instigator = _channeling_state.get("instigator", null)
	var input_target = _channeling_state.get("input_target", null)
	var context = _channeling_state.get("context", {})
	
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		_interrupt_channeling(ability_comp, false)
		return
	
	# 执行 Tick，如果失败则中断
	if not _perform_tick(ability_comp, instigator, input_target, context):
		_interrupt_channeling(ability_comp, false)

## Duration Timer 回调（引导完成）
func _on_duration_timeout() -> void:
	if not _channeling_state.get("is_active", false):
		return
	
	var ability_comp = _channeling_state.get("ability_comp", null)
	var instigator = _channeling_state.get("instigator", null)
	var input_target = _channeling_state.get("input_target", null)
	var context = _channeling_state.get("context", {})
	
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		_interrupt_channeling(ability_comp, false)
		return
	
	# 应用完成效果（会自动订阅阻塞 Effect）
	if not completion_effects.is_empty():
		var final_targets = _resolve_targets(instigator, input_target, context)
		_apply_effects_to_targets(completion_effects, instigator, final_targets, context)
	
	# 正常结束引导
	_interrupt_channeling(ability_comp, true)
