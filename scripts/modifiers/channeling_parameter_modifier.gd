extends GameplayAbilityModifier
class_name ChannelingParameterModifier

## 引导技能参数修改器
## 效果：修改引导类技能的参数（tick_interval、max_duration、is_mobile 等）
##
## 使用场景：
## - 天赋："急速引导"（减少 tick_interval，加快伤害频率）
## - 天赋："持久引导"（增加 max_duration，延长引导时间）
## - 天赋："移动引导"（将 is_mobile 设为 true，允许移动引导）
## - 装备词条："引导强化"（同时修改多个参数）

@export_group("Tick Interval Modifications")
## Tick 间隔修改（乘法）
## 例如：0.5 表示将 tick_interval 减半（加快频率）
## 例如：2.0 表示将 tick_interval 翻倍（减慢频率）
## 多个修改器会累乘：0.5 * 0.8 = 0.4（最终为原来的 40%）
@export_range(0.01, 10.0, 0.01) var tick_interval_multiplier: float = 1.0

@export_group("Max Duration Modifications")
## 最大持续时间修改（加法，秒）
## 例如：2.0 表示增加 2 秒最大持续时间
## 多个修改器会累加：2.0 + 3.0 = 5.0（总共增加 5 秒）
@export var max_duration_additive: float = 0.0
## 最大持续时间修改（乘法）
## 例如：1.5 表示将 max_duration 增加 50%
## 多个修改器会累乘：1.5 * 1.2 = 1.8（最终为原来的 180%）
@export_range(0.0, 10.0, 0.01) var max_duration_multiplier: float = 1.0

@export_group("Mobility Modifications")
## 是否强制允许移动引导
## 如果为 true，会将 is_mobile 设为 true（即使原技能不允许移动）
## 如果为 false，不修改 is_mobile
@export var force_mobile: bool = false

## 钩子：施法前（修改黑板参数）
## 在技能激活前修改黑板中的引导参数，这样行为树节点就能读取到修改后的值
func on_before_ability_cast(
	ability_comp: GameplayAbilityComponent,
	ability_instance: GameplayAbilityInstance,
	context: Dictionary
) -> void:
	# 检查是否影响此技能
	if not affects_ability(ability_instance, ability_comp):
		return
	
	# 检查是否是引导类技能（通过检查是否有 channeling_tick_interval 参数）
	var blackboard = ability_instance.get_blackboard()
	if not is_instance_valid(blackboard):
		return
	
	# 如果黑板中没有引导参数，说明不是引导类技能，直接返回
	if not blackboard.has_var("channeling_tick_interval"):
		return
	
	# 修改 tick_interval（乘法）
	if tick_interval_multiplier != 1.0:
		var current_interval = blackboard.get_var("channeling_tick_interval", 0.5)
		var new_interval = current_interval * tick_interval_multiplier
		blackboard.set_var("channeling_tick_interval", new_interval)
		print("ChannelingParameterModifier: Modified tick_interval from %.2f to %.2f (multiplier: %.2f)" % [
			current_interval, new_interval, tick_interval_multiplier
		])
	
	# 修改 max_duration（加法和乘法）
	if max_duration_additive != 0.0 or max_duration_multiplier != 1.0:
		var current_duration = blackboard.get_var("channeling_max_duration", 0.0)
		if current_duration > 0.0:  # 只有设置了最大持续时间才修改
			var new_duration = (current_duration + max_duration_additive) * max_duration_multiplier
			blackboard.set_var("channeling_max_duration", new_duration)
			print("ChannelingParameterModifier: Modified max_duration from %.2f to %.2f (additive: %.2f, multiplier: %.2f)" % [
				current_duration, new_duration, max_duration_additive, max_duration_multiplier
			])
		elif max_duration_additive > 0.0:  # 如果原来没有最大持续时间，但设置了加法，则设置新值
			blackboard.set_var("channeling_max_duration", max_duration_additive)
			print("ChannelingParameterModifier: Set max_duration to %.2f (additive: %.2f)" % [
				max_duration_additive, max_duration_additive
			])
	
	# 修改 is_mobile（强制允许移动）
	if force_mobile:
		blackboard.set_var("channeling_is_mobile", true)
		print("ChannelingParameterModifier: Force enabled mobile channeling")

