extends GameplayAbilityFeature
class_name ToggleFeature

## 切换特性
## 描述一个技能是"可切换"的
##
## 用途：
## - 允许在技能已激活时重新激活来执行关闭逻辑
## - 切换类技能的行为树应该检查黑板中的 "toggle_action" 变量来决定执行开启还是关闭逻辑
##
## 使用方式：
## ```gdscript
## var ability = GameplayAbilityDefinition.new()
## var toggle_feature = ToggleFeature.new()
## ability.features.append(toggle_feature)
## ```

func _init() -> void:
	super("ToggleFeature")

## 检查是否可以激活（允许在技能已激活时重新激活）
func can_activate(ability: GameplayAbilityInstance, context: AbilityContext) -> bool:
	# 如果技能已激活，说明这是关闭操作
	# 关闭操作应该跳过 cost 和 cooldown 检查（因为关闭不应该消耗资源或受冷却限制）
	if ability.is_active:
		context.skip_cost = true
		context.skip_cooldown = true
		return true
	
	# 如果技能未激活，这是正常的开启操作，不设置 skip 标志
	# 让其他 feature（如 CostFeature、CooldownFeature）正常检查
	return true

## 在技能激活时处理切换逻辑
## 通过检查 is_first_activation 标志来判断是首次激活还是关闭操作
func on_activate(ability: GameplayAbilityInstance, context: AbilityContext) -> void:
	var blackboard = ability.get_blackboard()
	if not is_instance_valid(blackboard):
		return
	
	# 检查是否是首次激活（开启操作）
	# is_first_activation 标志在 try_activate 中设置，用于区分首次激活和关闭操作
	var is_first_activation = blackboard.get_var("is_first_activation", false)
	
	if is_first_activation:
		# 首次激活（开启操作），设置"开启"标记
		blackboard.set_var("toggle_action", "turn_on")
		# 清除标志，避免影响后续判断
		blackboard.erase_var("is_first_activation")
	else:
		# 关闭操作（技能已激活时再次激活）
		blackboard.set_var("toggle_action", "turn_off")
		
		# 重置行为树，准备执行关闭逻辑
		var bt_instance = ability.get_bt_instance()
		if is_instance_valid(bt_instance):
			bt_instance.reset_tree()
