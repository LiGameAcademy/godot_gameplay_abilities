extends Resource
class_name GameplayTag

## 游戏标签资源
## 定义游戏状态的唯一标识和UI表现

## 逻辑ID，必须全局唯一。建议使用点号分隔的层级结构 (如 "status.burn")
## 代码中将使用此 ID 进行逻辑判断
@export var id: StringName = &""

@export_group("UI Presentation")
## 显示名称
@export var display_name: String = "Tag Name"
## 描述（多行文本）
@export_multiline var description: String = "Description of this state."
## 图标
@export var icon: Texture2D
## 边框颜色（用于UI显示）
@export var border_color: Color = Color.WHITE

@export_group("Tag Relations")
## 父标签ID（用于标签继承，如 "status.stun" 继承自 "status"）
## 支持多级继承，如 "status.debuff.stun" 继承自 "status.debuff"，再继承自 "status"
@export var parent_tag_id: StringName = &""
## 互斥标签列表（与此标签互斥的标签ID列表）
## 当添加此标签时，会自动移除互斥标签；反之亦然
@export var mutually_exclusive_tags: Array[StringName] = []
