extends Panel
class_name StatusTooltip

## 状态 Tooltip 控件
## 显示状态的详细信息

# UI 节点引用
@onready var tooltip_label: RichTextLabel = %TooltipLabel

# 状态实例引用
var _status_instance: GameplayStatusInstance = null

## 设置状态实例并更新显示
## [param] status_instance: GameplayStatusInstance 状态实例
func setup(status_instance: GameplayStatusInstance) -> void:
	_status_instance = status_instance
	_update_display()

## 更新显示内容
func _update_display() -> void:
	if not is_instance_valid(_status_instance) or not is_instance_valid(_status_instance.status_data):
		return
	
	var status_data = _status_instance.status_data
	var tooltip_content = _build_tooltip_text(_status_instance, status_data)
	
	if tooltip_label:
		tooltip_label.text = tooltip_content

## 构建 tooltip 文本
func _build_tooltip_text(status_instance: GameplayStatusInstance, status_data: GameplayStatusData) -> String:
	var text = "[b]%s[/b]\n" % status_data.status_display_name
	text += "%s\n\n" % status_data.status_description
	
	# 状态ID
	text += "[color=gray]ID: %s[/color]\n" % status_data.status_id
	
	# 层数
	if status_instance.stacks > 1:
		text += "层数: %d / %d\n" % [status_instance.stacks, status_data.max_stacks]
	
	# 持续时间
	if status_data.duration > 0:
		var remaining_time = 0.0
		if is_instance_valid(status_instance._duration_timer):
			remaining_time = status_instance._duration_timer.time_left
		text += "剩余时间: %.1f 秒\n" % remaining_time
	elif status_data.duration == -1:
		text += "持续时间: 永久\n"
	
	# 周期
	if status_data.period > 0:
		text += "周期: %.1f 秒\n" % status_data.period
	
	# 标签
	if not status_data.tags.is_empty():
		text += "标签: %s\n" % ", ".join(status_data.tags.map(func(t): return str(t)))
	
	return text

