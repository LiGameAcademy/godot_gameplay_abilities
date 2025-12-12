extends ActiveAbility
class_name ToggleAbility

## 切换技能数据（基类）
## 可以在开启和关闭状态之间切换的技能
## 
## 设计理念：
## - 切换技能：可以主动开关的技能（如光环、持续效果）
## - 引导技能：继承自切换技能，可以主动开关且可以被动关闭的技能（可以被打断）
##
## 子类需要实现：
## - `is_toggled_on()`: 检查技能是否处于开启状态
## - `can_toggle_off()`: 检查是否可以关闭技能（用于再次按下快捷键时）

@export_group("Toggle Ability")
@export var toggled_off_icon: Texture2D  ## 关闭状态的图标
@export var toggled_off_status_to_apply: GameplayStatusData = null  ## 关闭状态时应用的状态

## 检查技能是否处于开启状态
## 子类应该重写此方法以实现自己的状态检查逻辑
## [param] ability_comp: Node 技能组件
## [return] bool 是否处于开启状态
func is_toggled_on(ability_comp: Node) -> bool:
	# 默认实现：检查技能是否正在执行
	if not is_instance_valid(ability_comp):
		return false
	return ability_comp.get_current_casting_ability_id() == ability_id

## 检查是否可以关闭技能
## 当技能处于开启状态时，再次调用 commit_cast 应该关闭技能
## 子类应该重写此方法以实现自己的关闭条件检查
## [param] ability_comp: Node 技能组件
## [param] context: Dictionary 上下文信息
## [return] bool 是否可以关闭
func can_toggle_off(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 默认实现：如果技能正在执行，可以关闭
	return is_toggled_on(ability_comp)

## 重写：获取技能图标
## 根据切换状态返回不同的图标
## 按钮图标反映"按下会发生什么"：
## - 如果技能处于开启状态，显示关闭状态图标（表示按下会关闭）
## - 如果技能处于关闭状态，显示开启状态图标（表示按下会开启）
## [param] ability_comp: Node 技能组件（可选）
## [return] Texture 技能图标
func get_icon(ability_comp: Node = null) -> Texture:
	# 如果提供了 ability_comp，根据切换状态返回不同图标
	if is_instance_valid(ability_comp):
		# 如果技能处于开启状态，显示关闭状态图标（表示按下会关闭）
		if is_toggled_on(ability_comp):
			if is_instance_valid(toggled_off_icon):
				return toggled_off_icon
		# 如果技能处于关闭状态，显示开启状态图标（表示按下会开启）
		# 这里返回默认图标即可
	# 默认返回基础图标（开启状态）
	return super.get_icon(ability_comp)

## ToggleAbility 属于可切换技能（用于避免外部类型判断）
func is_toggleable() -> bool:
	return true

func _can_cast(ability_comp: Node, target: Node = null, context: Dictionary = {}) -> bool:
	# 如果已经开启，可以关闭（跳过冷却和消耗检查）
	if is_toggled_on(ability_comp) and can_toggle_off(ability_comp, context):
		return true
	# 否则检查正常施法条件
	return super._can_cast(ability_comp, target, context)

func _commit_cast(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 如果已经开启，关闭技能（跳过消耗和冷却）
	if is_toggled_on(ability_comp) and can_toggle_off(ability_comp, context):
		# 调用关闭逻辑
		_toggle_off(ability_comp, context)
		return true
	
	# 否则正常开启技能
	return super(ability_comp, context)

func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	# _on_cast() 只在开启时调用，关闭逻辑在 _commit_cast 中通过 _toggle_off() 处理
	# 所以这里只需要处理开启时的状态应用
	if not is_instance_valid(ability_comp) or not is_instance_valid(input_target): 
		return
	
	# 使用鸭子类型查询GameplayStatusComponent
	var target_status_comp = GameplayAbilitySystem.get_component_by_interface(input_target, "GameplayStatusComponent")
	if not is_instance_valid(target_status_comp):
		# 如果没有状态组件，直接返回（不是所有切换技能都需要状态系统）
		return
	
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	
	# 开启：应用开启状态
	# 注意：_on_cast() 只在开启时调用，所以这里总是应用开启状态
	if is_instance_valid(status_to_apply) and target_status_comp.has_method("apply_status"):
		target_status_comp.apply_status(status_to_apply, instigator)

## 关闭技能（虚方法，子类可以重写）
## [param] ability_comp: Node 技能组件
## [param] context: Dictionary 上下文信息
func _toggle_off(ability_comp: Node, context: Dictionary = {}) -> void:
	# 移除开启状态，应用关闭状态（如果需要）
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if is_instance_valid(instigator):
		var target_status_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayStatusComponent")
		if is_instance_valid(target_status_comp):
			# 移除开启状态
			if is_instance_valid(status_to_apply) and target_status_comp.has_method("remove_status"):
				target_status_comp.remove_status(status_to_apply.status_id)
			# 应用关闭状态（如果需要）
			if is_instance_valid(toggled_off_status_to_apply) and target_status_comp.has_method("apply_status"):
				target_status_comp.apply_status(toggled_off_status_to_apply, instigator)
	
	# 取消技能执行
	if ability_comp.has_method("cancel_ability"):
		ability_comp.cancel_ability(ability_id, context)
