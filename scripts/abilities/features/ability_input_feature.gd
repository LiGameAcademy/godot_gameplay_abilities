extends GameplayAbilityFeature
class_name AbilityInputFeature

## 输入特性
## 为技能绑定 Input Map Action 或物理按键

@export_group("Input")
## 绑定的输入动作名称 (如 "skill_q", "attack")
## 建议在 Project Settings -> Input Map 中配置对应的 Action
@export var input_action: StringName = &""

func _init() -> void:
	super("AbilityInputFeature")

## [核心API] 检查输入事件是否匹配
## 业务层在收到输入时调用此方法进行筛选
func match_input(event: InputEvent) -> bool:
	if input_action.is_empty():
		return false

	# 1. 优先检查 Input Map Action (支持改键)
	if InputMap.has_action(input_action):
		return event.is_action_pressed(input_action)

	# 2. 回退检查物理按键字符串 (仅用于快速原型)
	if event is InputEventKey and event.pressed and not event.echo:
		return event.as_text_key_label() == input_action

	return false

## [UI支持] 获取显示的快捷键文本 (供 AbilityButton 使用)
func get_key_text() -> String:
	if input_action.is_empty(): return ""

	# 如果是 Action，获取第一个绑定的物理键名
	if InputMap.has_action(input_action):
		var events = InputMap.action_get_events(input_action)
		if events.size() > 0:
			var event = events[0]
			# 简化显示逻辑：只取第一个字符或特定名称
			var text = event.as_text().split(" ")[0]
			return text.replace("Key", "") # 去掉多余前缀

	return input_action
