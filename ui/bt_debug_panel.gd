extends Window
class_name BTDebugPanel

## 行为树调试面板
## 用于可视化调试行为树的执行状态

const ENTITY_GROUP_NAME := "Entities"

@export_group("Debug Controls")
## 切换面板显示的快捷键（使用 Input Map 中的 action 名称）
@export var toggle_action: String = "toggle_bt_debug"

# UI 节点引用
@onready var entity_list: ItemList = %EntityList
@onready var tree_view: Tree = %TreeView
@onready var blackboard_view: RichTextLabel = %BlackboardView
@onready var active_nodes_view: RichTextLabel = %ActiveNodesView
@onready var execution_history_view: RichTextLabel = %ExecutionHistoryView
@onready var refresh_button: Button = %RefreshButton

# 实体数据 {entity_name: {node: Node, instance: GameplayAbilityInstance}}
var _entities: Dictionary = {}
var _selected_entity: Node = null
var _selected_instance: GameplayAbilityInstance = null

# 树视图根节点
var _tree_root_item: TreeItem = null

func _ready() -> void:
	# 连接信号
	entity_list.item_selected.connect(_on_entity_selected)
	refresh_button.pressed.connect(_on_refresh_pressed)
	
	# 初始隐藏窗口（调试面板默认隐藏）
	# 注意：现在脚本直接继承 Window，所以 self 就是窗口
	visible = false
	
	# 监听窗口关闭事件
	if not close_requested.is_connected(_on_window_close_requested):
		close_requested.connect(_on_window_close_requested)
	
	# 初始扫描
	_scan_entities()
	
	# 设置更新频率（每帧更新，但只在可见时）
	set_process(false)

func _process(_delta: float) -> void:
	if not visible:
		return
	
	if is_instance_valid(_selected_instance):
		_update_tree_view()
		_update_blackboard_view()
		_update_active_nodes_view()
		_update_execution_history_view()

## 处理未处理的输入事件（用于快捷键）
## 注意：Window 节点需要从主场景接收输入，所以这个方法可能不会被调用
## 建议在主场景中处理快捷键，然后调用 toggle_visibility()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle_visibility()
		get_viewport().set_input_as_handled()

## 切换面板显示/隐藏
## 这个方法应该从主场景调用（通过快捷键）
func toggle_visibility() -> void:
	if visible:
		# 隐藏窗口
		visible = false
		set_process(false)
	else:
		# 显示窗口（使用 popup_centered 确保窗口居中显示）
		popup_centered()
		# 显示时刷新实体列表
		_scan_entities()
		set_process(true)
		# 将窗口置于最前
		move_to_foreground()

## 窗口关闭请求回调
func _on_window_close_requested() -> void:
	visible = false
	set_process(false)

## 扫描场景中所有包含 GameplayAbilityComponent 的实体
func _scan_entities() -> void:
	_entities.clear()
	entity_list.clear()
	
	# 使用 Group 机制获取所有能力实体
	# 注意：如果 GameplayAbilityComponent 没有 GROUP_NAME，需要添加
	# 或者通过其他方式查找（如遍历场景树）
	var entities: Array[Node] = get_tree().get_nodes_in_group(ENTITY_GROUP_NAME)
	# 遍历实体，查找对应的 GameplayAbilityComponent
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		
		# 获取能力组件
		var ability_comp = GameplayAbilitySystem.get_component_by_interface(entity, "GameplayAbilityComponent")
		if not is_instance_valid(ability_comp) or not ability_comp is GameplayAbilityComponent:
			continue
		
		# 查找正在运行的技能实例
		var active_instance: GameplayAbilityInstance = null
		# 尝试获取当前正在执行的技能
		if ability_comp.has_method("get_current_casting_ability"):
			active_instance = ability_comp.get_current_casting_ability()
		elif "_current_casting_ability" in ability_comp:
			active_instance = ability_comp._current_casting_ability
		
		if not is_instance_valid(active_instance):
			# 如果没有正在运行的技能，尝试获取第一个技能实例
			if ability_comp.has_method("get_all_ability_ids"):
				var ability_ids = ability_comp.get_all_ability_ids()
				if ability_ids.size() > 0:
					active_instance = ability_comp.get_ability_instance(ability_ids[0])
		
		# 生成实体名称
		var entity_name = entity.name if entity.name != "" else str(entity.get_path())
		# 如果名称重复，添加路径信息
		if _entities.has(entity_name):
			entity_name = str(entity.get_path())
		
		_entities[entity_name] = {
			"node": entity,
			"instance": active_instance
		}
	
	# 更新列表显示
	for entity_name in _entities.keys():
		var data = _entities[entity_name]
		var display_name = entity_name
		if is_instance_valid(data.instance):
			var ability_id = data.instance.get_definition().ability_id
			display_name += " [%s]" % ability_id
		entity_list.add_item(display_name)
	
	# 如果有实体，默认选择第一个
	if entity_list.get_item_count() > 0:
		entity_list.select(0)
		_on_entity_selected(0)

## 实体选择回调
func _on_entity_selected(index: int) -> void:
	if index < 0 or index >= entity_list.get_item_count():
		return
	
	var entity_name = entity_list.get_item_text(index)
	# 提取原始名称（去掉 [ability_id] 部分）
	var base_name = entity_name.split(" [")[0]
	
	if not _entities.has(base_name):
		return
	
	var data = _entities[base_name]
	_selected_entity = data.node
	_selected_instance = data.instance
	
	# 更新视图
	_update_tree_view()
	_update_blackboard_view()
	_update_active_nodes_view()
	_update_execution_history_view()

## 刷新按钮回调
func _on_refresh_pressed() -> void:
	_scan_entities()

## 更新树视图
func _update_tree_view() -> void:
	tree_view.clear()
	_tree_root_item = null
	
	if not is_instance_valid(_selected_instance):
		return
	
	var bt_instance = _selected_instance._bt_instance
	if not is_instance_valid(bt_instance) or not is_instance_valid(bt_instance.tree_root):
		return
	
	# 递归构建树视图
	_tree_root_item = tree_view.create_item()
	_build_tree_item(_tree_root_item, bt_instance.tree_root, bt_instance)

## 递归构建树项
func _build_tree_item(parent_item: TreeItem, node: BTNode, instance: BTInstance) -> void:
	if not is_instance_valid(node):
		return
	
	# 获取节点名称
	var node_name = _get_node_name(node)
	
	# 检查节点是否正在运行（使用 _node_status，不干扰存储数据）
	var is_running = instance.has_node_status(node)
	
	# 确定状态文本和颜色
	var status_text = " [RUNNING]" if is_running else ""
	var status_color = Color.CYAN if is_running else Color.WHITE
	
	# 创建树项
	var item = tree_view.create_item(parent_item)
	item.set_text(0, node_name + status_text)
	item.set_custom_color(0, status_color)
	
	# 如果是组合节点，递归处理子节点
	if node is BTComposite:
		var composite = node as BTComposite
		for child in composite.children:
			_build_tree_item(item, child, instance)
	elif node is BTDecorator:
		var decorator = node as BTDecorator
		if is_instance_valid(decorator.child):
			_build_tree_item(item, decorator.child, instance)

## 获取节点名称
## 格式：名称[类型]
func _get_node_name(node: BTNode) -> String:
	if node == null:
		return "null"
	
	# 获取节点类型（类名）
	var node_type: String = ""
	var script = node.get_script()
	if script:
		var node_class_name = script.get_global_name()
		if node_class_name != "":
			node_type = node_class_name
		else:
			node_type = node.get_class()
	else:
		node_type = node.get_class()
	
	# 获取节点名称（使用节点的 _get_node_name 方法）
	var custom_name: String = ""
	if node.has_method("_get_node_name"):
		var name_result = node._get_node_name()
		if name_result is StringName:
			custom_name = name_result
		elif name_result is String:
			custom_name = name_result
	
	# 如果节点名称就是类型名（未设置自定义名称），只显示类型
	if custom_name == node_type or custom_name.is_empty():
		return "[%s]" % node_type
	else:
		# 格式化显示：名称[类型]
		return "%s[%s]" % [custom_name, node_type]

## 更新黑板视图
func _update_blackboard_view() -> void:
	var text = "[b]黑板变量[/b]\n\n"
	
	if not is_instance_valid(_selected_instance):
		text += "未选择实体或技能未激活"
		blackboard_view.text = text
		return
	
	var bt_instance = _selected_instance._bt_instance
	if not is_instance_valid(bt_instance):
		text += "行为树实例不存在"
		blackboard_view.text = text
		return
	
	# 获取所有黑板变量
	var blackboard = bt_instance.blackboard
	var all_vars = blackboard.get_all_vars()
	
	if all_vars.is_empty():
		text += "无黑板变量"
	else:
		for key in all_vars.keys():
			var value = all_vars[key]
			text += "[color=cyan]%s[/color]: %s\n" % [key, _format_value(value)]
	
	blackboard_view.text = text

## 更新活动节点视图
func _update_active_nodes_view() -> void:
	var text = "[b]活动节点[/b]\n\n"
	
	if not is_instance_valid(_selected_instance):
		text += "未选择实体或技能未激活"
		active_nodes_view.text = text
		return
	
	var bt_instance = _selected_instance._bt_instance
	if not is_instance_valid(bt_instance):
		text += "行为树实例不存在"
		active_nodes_view.text = text
		return
	
	# 获取所有活动节点（通过 BTBlackboard 的 get_all_node_data 方法）
	var blackboard = bt_instance.blackboard
	var active_nodes = blackboard.get_all_node_data()
	var active_count = active_nodes.size()
	
	text += "活动节点数量: %d\n\n" % active_count
	
	if active_count > 0:
		for node_info in active_nodes:
			var node_name = node_info.get("node_name", "unknown")
			var node_data = node_info.get("data", null)
			text += "[color=cyan]%s[/color]: %s\n" % [node_name, _format_value(node_data)]
	else:
		text += "无活动节点"
	
	active_nodes_view.text = text

## 更新执行记录视图
func _update_execution_history_view() -> void:
	var text = "[b]执行记录[/b]\n\n"
	
	if not is_instance_valid(_selected_instance):
		text += "未选择实体或技能未激活"
		execution_history_view.text = text
		return
	
	var bt_instance = _selected_instance._bt_instance
	if not is_instance_valid(bt_instance):
		text += "行为树实例不存在"
		execution_history_view.text = text
		return
	
	# 获取执行历史
	var history = bt_instance.get_execution_history()
	var history_count = history.size()
	
	text += "记录数量: %d\n\n" % history_count
	
	if history_count > 0:
		# 显示最近的记录（倒序，最新的在顶部）
		var display_count = min(history_count, 20)  # 最多显示20条
		for i in range(history_count - display_count, history_count):
			var record = history[i]
			var node = record.get("node", null)
			var status = record.get("status", -1)
			var timestamp = record.get("timestamp", 0.0)
			var frame = record.get("frame", 0)
			
			if not is_instance_valid(node):
				continue
			
			# 获取节点名称
			var node_name = _get_node_name(node)
			
			# 状态文本和颜色
			var status_text = ""
			var status_color = Color.WHITE
			match status:
				BTNode.Status.SUCCESS:
					status_text = "SUCCESS"
					status_color = Color.GREEN
				BTNode.Status.FAILURE:
					status_text = "FAILURE"
					status_color = Color.RED
				BTNode.Status.RUNNING:
					status_text = "RUNNING"
					status_color = Color.CYAN
				_:
					status_text = "UNKNOWN"
			
			# 格式化时间戳（保留2位小数）
			var time_str = "%.2f" % timestamp
			
			# 显示记录：[时间] 节点名称 -> 状态 (帧号)
			text += "[color=gray]%s[/color] [color=cyan]%s[/color] -> [color=%s]%s[/color] (帧:%d)\n" % [
				time_str,
				node_name,
				_status_color_to_hex(status_color),
				status_text,
				frame
			]
	else:
		text += "无执行记录"
	
	execution_history_view.text = text

## 将状态颜色转换为十六进制字符串（用于 BBCode）
func _status_color_to_hex(color: Color) -> String:
	return "#%02x%02x%02x" % [
		int(color.r * 255),
		int(color.g * 255),
		int(color.b * 255)
	]

## 格式化值显示
func _format_value(value: Variant) -> String:
	if value == null:
		return "[null]"
	
	if value is Node:
		return value.name if is_instance_valid(value) else "[invalid Node]"
	
	if value is Array:
		return "[Array: %d items]" % value.size()
	
	if value is Dictionary:
		return "[Dictionary: %d keys]" % value.size()
	
	return str(value)
