extends GameplayCueBase
class_name CueFloatingText

## 飘字 Cue
## 用于显示伤害、治疗等数值的浮动文本

@export_group("Text Settings")
## 飘字文本颜色
@export var text_color: Color = Color.WHITE
## 飘字字体大小
@export var text_font_size: int = 24
## 飘字向上移动的距离
@export var text_float_distance: float = 2.0
## 飘字持续时间（秒）
@export var text_duration: float = 1.0
## 飘字格式字符串（支持 {value} 占位符）
@export var text_format: String = "-{value}"

## 对象池引用（由 Manager 注入）
var _text_pool: Array[Label3D] = []
var _active_texts: Array[Label3D] = []
var _text_template: PackedScene = null

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	var text_node = _get_text_node()
	if not is_instance_valid(text_node):
		return
	
	# 设置文本内容
	var text_content: String = ""
	if context.has("final_damage"):
		var value = context["final_damage"]
		text_content = text_format.format({"value": int(value)})
	elif context.has("value"):
		var value = context["value"]
		text_content = text_format.format({"value": int(value)})
	elif context.has("text"):
		text_content = context["text"]
	else:
		text_content = text_format.replace("{value}", "")
	
	text_node.text = text_content
	text_node.modulate = text_color
	
	# 设置字体大小
	if text_node.has_method("add_theme_font_size_override"):
		text_node.add_theme_font_size_override("font_size", text_font_size)
	
	# 设置位置
	text_node.global_position = location
	
	# 添加到场景树
	var root = Engine.get_main_loop().root
	if not is_instance_valid(root):
		push_warning("CueFloatingText: Cannot show floating text, no valid root node")
		_recycle_text_node(text_node)
		return
	if not is_instance_valid(root):
		push_warning("CueFloatingText: Cannot show floating text, no valid root node")
		_recycle_text_node(text_node)
		return
	
	root.add_child(text_node)
	
	# 播放动画
	_play_animation(text_node)
	
	# 标记为使用中
	_active_texts.append(text_node)

## 播放飘字动画
func _play_animation(text_node: Label3D) -> void:
	# 使用全局单例 GameplayCueManager 创建 Tween
	var manager = GameplayCueManager
	if not is_instance_valid(manager):
		push_warning("CueFloatingText: Cannot create tween, GameplayCueManager not found")
		_recycle_text_node(text_node)
		return
	
	var tween = manager.create_tween()
	tween.set_parallel(true)
	
	# 向上移动
	var target_pos = text_node.global_position + Vector3(0, text_float_distance, 0)
	tween.tween_property(text_node, "global_position", target_pos, text_duration)
	
	# 淡出
	tween.tween_property(text_node, "modulate:a", 0.0, text_duration)
	
	# 添加轻微的随机偏移，避免重叠
	var random_offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	tween.tween_property(text_node, "global_position", target_pos + random_offset, text_duration)
	
	# 动画完成后回收
	tween.tween_callback(_recycle_text_node.bind(text_node)).set_delay(text_duration)

## 获取飘字节点（从对象池获取或创建新的）
func _get_text_node() -> Label3D:
	# 从对象池获取
	if not _text_pool.is_empty():
		var text = _text_pool.pop_back()
		text.visible = true
		text.modulate.a = 1.0
		return text
	
	# 对象池为空，创建新的
	if _text_pool.size() < 50:  # 最大池大小
		return _create_text_node()
	
	push_warning("CueFloatingText: Text pool exhausted")
	return null

## 创建新的飘字节点
func _create_text_node() -> Label3D:
	if is_instance_valid(_text_template):
		return _text_template.instantiate() as Label3D
	else:
		var label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.shaded = false
		label.no_depth_test = true
		return label

## 回收飘字节点到对象池
func _recycle_text_node(text_node: Label3D) -> void:
	if not is_instance_valid(text_node):
		return
	
	_active_texts.erase(text_node)
	text_node.visible = false
	text_node.modulate.a = 1.0
	text_node.text = ""
	
	if is_instance_valid(text_node.get_parent()):
		text_node.get_parent().remove_child(text_node)
	
	_text_pool.append(text_node)

## 初始化对象池（由 Manager 调用）
func initialize_pool(template: PackedScene, initial_size: int = 10) -> void:
	_text_template = template
	for i in range(initial_size):
		var text = _create_text_node()
		if is_instance_valid(text):
			_text_pool.append(text)

