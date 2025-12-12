extends ActiveAbility
class_name ChannelingAbility

## 引导类技能（持续施法，周期触发）
## 设计目标：
## - 支持持续时间 / 周期 Tick / 完成效果
## - 支持每 Tick 消耗、结束消耗跳过（由 context 控制）
## - 可配置是否允许移动、按键松开是否中断
## - 使用状态系统管理 tick 效果和资源消耗
## - 整合 ToggleAbility 的切换功能

const TAG_CHANNELING: StringName = &"state.casting.channeling"

@export_group("Channeling Settings")
## 引导状态（包含 tick 效果、资源消耗、完成效果）
## 状态系统会负责管理周期性触发和资源消耗
@export var channeling_status: GameplayStatusData = null
## 引导持续时间（如果状态未设置 duration，使用此值）
@export var channel_duration: float = 0.0
## 是否允许移动引导（false 时移动视为打断）
@export var is_mobile: bool = false
## 是否按住维持（true 时松开输入即打断，false 时为切换式引导）
@export var stop_on_input_release: bool = true

@export_group("Toggle Ability")
## 关闭状态的图标
@export var toggled_off_icon: Texture2D = null
## 关闭状态时应用的状态（可选）
@export var toggled_off_status_to_apply: GameplayStatusData = null

## 引导状态（运行时数据）
var _channeling_state: Dictionary = {}  ## 存储引导状态：ability_comp, instigator, input_target, context, input_action
var _is_active: bool = false:  ## 引导是否处于激活状态
	set(value):
		_is_active = value

## 每帧更新（检查中断条件）
func update(delta: float) -> void:
	if not _is_active:
		return
	
	var instigator = _channeling_state.get("instigator", null)
	var input_action: String = _channeling_state.get("input_action", "")
	var shortcut_checker: Callable = _channeling_state.get("shortcut_checker", Callable())
	
	# 有效性检查
	if not is_instance_valid(instigator):
		_interrupt_channeling(false)
		return
	
	# 中断条件：按键松开（支持 Input Action 和快捷键 Callable）
	if stop_on_input_release:
		var is_pressed = false
		
		# 检查 Input Action
		if input_action != "":
			is_pressed = Input.is_action_pressed(input_action)
		
		# 检查快捷键（通过 Callable）
		if not is_pressed and shortcut_checker.is_valid():
			is_pressed = shortcut_checker.call()
		
		# 如果按键已松开，中断引导
		if not is_pressed:
			_interrupt_channeling(false)
			return
	
	# 中断条件：不允许移动且角色在移动（需角色实现 is_moving）
	if not is_mobile and instigator.has_method("is_moving") and instigator.is_moving():
		_interrupt_channeling(false)
		return

## 检查技能是否处于开启状态
func is_toggled_on() -> bool:
	return _is_active

## 检查是否可以关闭技能
## 切换式引导（stop_on_input_release = false）可以主动关闭
## 按住维持式引导（stop_on_input_release = true）只能被动关闭（松开按键）
func can_toggle_off(_context: Dictionary = {}) -> bool:
	# 只有切换式引导（stop_on_input_release = false）可以主动关闭
	return not stop_on_input_release

## 重写：获取技能图标
## 根据切换状态返回不同的图标
func get_icon() -> Texture:
	# 如果技能处于开启状态，显示关闭状态图标（表示按下会关闭）
	if is_toggled_on():
		if is_instance_valid(toggled_off_icon):
			return toggled_off_icon
	# 如果技能处于关闭状态，显示开启状态图标（表示按下会开启）
	# 这里返回默认图标即可
	# 默认返回基础图标（开启状态）
	return super()

## ToggleAbility 属于可切换技能（用于避免外部类型判断）
func is_toggleable() -> bool:
	return true

## 施放入口
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ChannelingAbility: Cannot cast, instigator is not valid")
		return
	
	# 如果已经在引导，先取消之前的引导（这种情况不应该发生，因为关闭时会清空状态）
	# 但为了安全起见，保留这个检查
	if _is_active:
		_interrupt_channeling(false)
		# 如果是在关闭后立即重新开启，这里已经清理了状态，可以继续执行
	
	# 记录输入动作，供"按住维持"模式检测
	var input_action: String = context.get("input_action", "")
	
	# 获取快捷键检查器（Callable，用于检查快捷键是否按下）
	# 如果 context 中提供了 shortcut_checker，使用它；否则尝试从外部获取
	var shortcut_checker: Callable = context.get("shortcut_checker", Callable())

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
		"shortcut_checker": shortcut_checker
	}
	_is_active = true
	
	# 应用引导状态（状态系统会负责管理 tick 效果和资源消耗）
	if is_instance_valid(channeling_status):
		var status_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayStatusComponent")
		if is_instance_valid(status_comp):
			# 如果状态未设置 duration，使用 channel_duration
			# 注意：我们需要克隆状态数据以避免修改资源
			var status_to_apply = channeling_status
			if channeling_status.duration <= 0.0 and channel_duration > 0.0:
				# 克隆状态数据并设置 duration
				status_to_apply = channeling_status.duplicate(true) as GameplayStatusData
				status_to_apply.duration = channel_duration
			
			# 订阅状态移除事件，用于处理完成效果
			if not status_comp.status_removed.is_connected(_on_channeling_status_removed):
				status_comp.status_removed.connect(_on_channeling_status_removed)
			
			# 存储状态ID，用于后续移除
			_channeling_state["status_id"] = status_to_apply.status_id
			
			status_comp.apply_status(status_to_apply, instigator, 1, context)
		else:
			push_warning("ChannelingAbility: Instigator has no GameplayStatusComponent!")
	else:
		push_warning("ChannelingAbility: channeling_status is not set for ability %s" % ability_id)
	
	# 检查是否所有效果都已完成（如果没有效果被应用，立即完成技能）
	_check_ability_completion()

## 中断引导（内部方法）
## [param] completed: bool 是否正常完成（true 表示完成，false 表示中断）
func _interrupt_channeling(completed: bool = false) -> void:
	# 如果已经不在激活状态，直接返回（避免重复调用）
	if not _is_active:
		return
	
	_is_active = false
	
	# 标记是否正常完成（用于后续处理完成效果）
	_channeling_state["completed"] = completed
	
	# 移除引导状态（状态系统会负责清理效果和资源消耗）
	# 注意：状态移除会触发 _on_channeling_status_removed，在那里处理完成效果
	var instigator = _channeling_state.get("instigator", null)
	if is_instance_valid(instigator):
		var status_id = _channeling_state.get("status_id", "")
		if status_id != "":
			var status_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayStatusComponent")
			if is_instance_valid(status_comp):
				status_comp.remove_status(status_id)
	
	# 清理所有正在运行的效果实例（包括停止持续 Cue）
	# 遍历 _pending_effects 中的所有效果实例，调用 remove() 方法正确清理
	for effect_inst in _pending_effects.keys():
		if is_instance_valid(effect_inst):
			# remove() 方法会调用 _stop_cue() 来停止持续 Cue
			effect_inst.remove(instigator, instigator)
	
	# 通知技能完成（引导结束时）
	ability_completed.emit(self)
	
	# 清空状态
	_channeling_state.clear()
	_is_active = false

## 关闭技能
func _toggle_off(ability_comp: Node, context: Dictionary = {}) -> void:
	# 先中断引导（清理状态和 Cue）
	_interrupt_channeling(false)
	
	# 处理关闭状态（如果需要）
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if is_instance_valid(instigator):
		var target_status_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayStatusComponent")
		if is_instance_valid(target_status_comp):
			# 移除开启状态（如果使用了 status_to_apply）
			if is_instance_valid(status_to_apply):
				target_status_comp.remove_status(status_to_apply.status_id)
			# 应用关闭状态（如果需要）
			if is_instance_valid(toggled_off_status_to_apply):
				target_status_comp.apply_status(toggled_off_status_to_apply, instigator)
	
	# 取消技能执行
	ability_comp.cancel_ability(ability_id, context)

func _can_cast(ability_comp: Node, target: Node = null, context: Dictionary = {}) -> bool:
	# 如果已经开启，可以关闭（跳过冷却和消耗检查）
	if is_toggled_on() and can_toggle_off(context):
		return true
	# 否则检查正常施法条件
	return super(ability_comp, target, context)

func _commit_cast(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 如果已经开启，关闭技能（跳过消耗和冷却）
	if is_toggled_on() and can_toggle_off(context):
		# 调用关闭逻辑（_toggle_off 内部会调用 cancel_ability 来取消计时器和清除状态）
		_toggle_off(ability_comp, context)
		
		# 返回 true 表示操作成功（关闭操作也是成功的操作）
		return true
	
	# 否则正常开启技能
	return super(ability_comp, context)

## 技能被取消时的处理
func _on_cancel(ability_comp: Node, context: Dictionary = {}) -> void:
	# 如果已经在 _toggle_off 中调用了 _interrupt_channeling，这里会直接返回（避免重复调用）
	_interrupt_channeling(false)

## 引导状态移除回调（用于处理完成效果）
## [param] status_id: StringName 被移除的状态ID
func _on_channeling_status_removed(status_id: StringName) -> void:
	# 检查是否是我们的引导状态
	if not is_instance_valid(channeling_status) or status_id != channeling_status.status_id:
		return
	
	# 检查是否正常完成（需要应用完成效果）
	# 注意：完成效果应该配置在引导状态中，通过状态移除事件触发
	# 或者通过 GE_ApplyStatus 在状态中应用另一个状态来实现
	# 这里暂时不处理，完成效果应该在引导状态中配置
	pass
