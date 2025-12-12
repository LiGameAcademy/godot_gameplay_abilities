extends MarginContainer
class_name StatusIcon

## 状态图标控件
## 显示单个状态的图标、层数等信息，支持 tooltip

# Tooltip 场景预制体
const STATUS_TOOLTIP_SCENE = preload("res://addons/godot_gameplay_abilities/ui/status_tooltip.tscn")

# UI 节点引用
@onready var texture_rect: TextureRect = %TextureRect
@onready var stack_label: Label = %StackLabel

# 状态实例引用
var _status_instance: GameplayStatusInstance = null

func _ready() -> void:
	# 初始隐藏层数标签
	if stack_label:
		stack_label.visible = false
	
	# 设置 tooltip_text（必须设置，_make_custom_tooltip 才能正常工作）
	tooltip_text = "Status"

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
	if texture_rect and is_instance_valid(status_data.icon):
		texture_rect.texture = status_data.icon
	
	# 更新层数显示
	update_stack_display()

## 更新层数显示（公共方法，供外部调用）
func update_stack_display() -> void:
	if not is_instance_valid(_status_instance):
		return
	
	var stacks = _status_instance.stacks
	if stack_label:
		if stacks > 1:
			stack_label.text = str(stacks)
			stack_label.visible = true
		else:
			stack_label.visible = false

## 创建自定义 Tooltip（Godot 内置方法）
## [param] for_text: String tooltip 文本（不使用，但必须保留参数）
## [returns] Control tooltip 控件
func _make_custom_tooltip(_for_text: String) -> Control:
	if not is_instance_valid(_status_instance):
		return null
	
	# 实例化 tooltip 场景
	var tooltip = STATUS_TOOLTIP_SCENE.instantiate()
	if not is_instance_valid(tooltip) or not tooltip.has_method("setup"):
		return null
	
	# 设置状态实例
	tooltip.setup(_status_instance)
	
	return tooltip
