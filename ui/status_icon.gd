extends MarginContainer
class_name StatusIcon

## 状态图标控件
## 显示单个状态的图标、层数等信息，支持 tooltip

# UI 节点引用
@onready var texture_rect: TextureRect = %TextureRect
@onready var stack_label: Label = %StackLabel

# 状态实例引用
var _status_instance: GameplayStatusInstance = null

func _ready() -> void:
	# 初始隐藏层数标签
	if is_instance_valid(stack_label):
		stack_label.visible = false

	# 设置 tooltip_text（必须设置，_make_custom_tooltip 才能正常工作）
	tooltip_text = "Status"
	update_stack_display()

func _process(delta: float) -> void:
	if not is_instance_valid(_status_instance):
		return
	tooltip_text = _build_tooltip_text(_status_instance, _status_instance.status_data)

## 设置状态实例
## [param] status_instance: GameplayStatusInstance 状态实例
func setup(status_instance: GameplayStatusInstance) -> void:
	_status_instance = status_instance

	if not is_instance_valid(status_instance) or not is_instance_valid(status_instance.status_data):
		return
	
	var status_data = status_instance.status_data

	if not is_instance_valid(texture_rect):
		texture_rect = %TextureRect

	# 设置图标
	if is_instance_valid(texture_rect) and is_instance_valid(status_data.icon):
		texture_rect.texture = status_data.icon

	# 更新层数显示
	update_stack_display()

## 更新层数显示（公共方法，供外部调用）
func update_stack_display() -> void:
	if not is_instance_valid(_status_instance):
		return
	var stacks = _status_instance.stacks
	if is_instance_valid(stack_label):
		if stacks > 1:
			stack_label.text = str(stacks)
			stack_label.visible = true
		else:
			stack_label.visible = false

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
		var remaining_time = status_instance.remaining_duration
		text += "剩余时间: %.1f 秒\n" % remaining_time

	elif status_data.duration == -1:
		text += "持续时间: 永久\n"

	# 标签
	if not status_data.tags.is_empty():
		text += "标签: %s\n" % ", ".join(status_data.tags.map(func(t): return str(t)))

	return text
