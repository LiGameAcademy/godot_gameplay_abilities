extends Resource
class_name GameplayTag

## 游戏标签资源
## 定义游戏状态的唯一标识和UI表现

#region ========== 核心标识 ==========

## 逻辑ID，必须全局唯一。建议使用 snake_case (如 "fire_immune")
## 代码中将使用此 ID 进行逻辑判断
@export var id: StringName = &""

#endregion

#region ========== UI 表现 ==========

@export_group("UI Presentation")

## 显示名称
@export var display_name: String = "Tag Name"

## 描述（多行文本）
@export_multiline var description: String = "Description of this state."

## 图标
@export var icon: Texture2D

## 边框颜色（用于UI显示）
@export var border_color: Color = Color.WHITE

#endregion

#region ========== 分类 ==========

@export_group("Category")

## 标签分类
## Status: 状态类（如眩晕、沉默）
## Mechanic: 机制类（如飞行、亡灵）
## Element: 元素类（如潮湿、燃烧）
## Immunity: 免疫类（如火免疫、控制免疫）
var category: String = "Status"

#endregion

#region ========== 标签关系 ==========

@export_group("Tag Relations")

## 父标签ID（用于标签继承，如 "status.stun" 继承自 "status"）
## 支持多级继承，如 "status.debuff.stun" 继承自 "status.debuff"，再继承自 "status"
@export var parent_tag_id: StringName = &""

## 互斥标签列表（与此标签互斥的标签ID列表）
## 当添加此标签时，会自动移除互斥标签；反之亦然
@export var mutually_exclusive_tags: Array[StringName] = []

#endregion

func _init(p_id: StringName = &"", p_display_name: String = "") -> void:
	id = p_id
	if not p_display_name.is_empty():
		display_name = p_display_name

## 验证标签资源（编辑器验证）
## 在编辑器中调用，用于验证标签配置
func _validate_property(property: Dictionary) -> void:
	var property_name = property.get("name", "")
	
	# 验证 ID 不能为空
	if property_name == "id":
		if id == &"":
			property["usage"] = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR
			property["hint_string"] = "Tag ID cannot be empty"
	
	# 验证父标签不能是自身
	if property_name == "parent_tag_id":
		if parent_tag_id == id:
			property["usage"] = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR
			property["hint_string"] = "Parent tag cannot be the same as the tag itself"
	
	# 验证互斥标签不能包含自身
	if property_name == "mutually_exclusive_tags":
		if mutually_exclusive_tags.has(id):
			property["usage"] = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR
			property["hint_string"] = "Tag cannot be mutually exclusive with itself"

