extends MarginContainer
class_name AttributeRow

## 属性行UI组件
## 显示单个属性的名称、图标、数值和操作按钮

# UI 节点引用
@onready var icon_texture = %IconTexture
@onready var info_container = %InfoContainer
@onready var label_name = %NameLabel
@onready var label_description = %DescriptionLabel
@onready var value_container = %ValueContainer
@onready var label_value = %ValueLabel
@onready var btn_increase = %IncreaseButton

# 数据
var attribute_id: StringName
var attribute_resource: GameplayAttribute
var _comp: GameplayAttributeComponent
var _can_increase: bool = false

# 信号：当点击增加按钮时发出
signal increase_requested(attr_id: StringName)

func _ready() -> void:
	# 连接按钮信号
	if btn_increase:
		btn_increase.pressed.connect(_on_increase_pressed)

## 设置属性行
## [param] comp: GameplayAttributeComponent 属性组件
## [param] attr_res: GameplayAttribute 属性资源
## [param] can_increase: bool 是否允许增加
func setup(comp: GameplayAttributeComponent, attr_res: GameplayAttribute, can_increase: bool) -> void:
	_comp = comp
	attribute_resource = attr_res
	attribute_id = attr_res.attribute_id
	_can_increase = can_increase
	
	# 更新UI显示
	_update_display()
	
	# 显示/隐藏增加按钮
	if btn_increase:
		btn_increase.visible = can_increase

## 更新数值显示
## [param] new_value: float 新的属性值
func update_display(new_value: float) -> void:
	if label_value:
		label_value.text = _format_value(new_value)

## 更新完整显示（包括名称、图标等）
func _update_display() -> void:
	if not attribute_resource:
		return
	
	# 更新图标
	if icon_texture and attribute_resource.attribute_icon:
		icon_texture.texture = attribute_resource.attribute_icon
		icon_texture.visible = true
	else:
		if icon_texture:
			icon_texture.visible = false
	
	# 更新名称
	if label_name:
		label_name.text = attribute_resource.attribute_display_name
	
	# 更新描述
	if label_description:
		if attribute_resource.attribute_description.is_empty():
			label_description.visible = false
		else:
			label_description.text = attribute_resource.attribute_description
			label_description.visible = true
	
	# 更新数值
	var current_value = _comp.get_value(attribute_id)
	if label_value:
		label_value.text = _format_value(current_value)

## 格式化数值显示
## [param] value: float 属性值
## [return] String 格式化后的字符串
func _format_value(value: float) -> String:
	if not attribute_resource:
		return str(int(value))
	
	# 百分比显示
	if attribute_resource.is_percentage:
		return "%.1f%%" % (value * 100.0)
	
	# 整数显示
	return str(int(value))

## 增加按钮点击回调
func _on_increase_pressed() -> void:
	increase_requested.emit(attribute_id)
