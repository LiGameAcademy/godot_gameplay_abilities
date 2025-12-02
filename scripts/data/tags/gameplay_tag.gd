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

func _init(p_id: StringName = &"", p_display_name: String = "") -> void:
	id = p_id
	if not p_display_name.is_empty():
		display_name = p_display_name

