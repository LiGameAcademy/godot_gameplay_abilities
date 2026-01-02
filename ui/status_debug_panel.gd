extends MarginContainer
class_name StatusDebugPanel

## 状态调试面板
## 用于调试和管理实体的状态系统

const ENTITY_GROUP : String = "Entities"

# 状态图标预制体
@export var STATUS_ICON_PREFAB : PackedScene = null

@onready var refresh_button: Button = %RefreshButton
@onready var entity_list: ItemList = %EntityList
@onready var status_container: HBoxContainer = %StatusContainer
@onready var status_id_input: LineEdit = %StatusIdInput
@onready var add_status_button: Button = %AddStatusButton
@onready var remove_status_button: Button = %RemoveStatusButton

@export_group("Status Resource Loading")
## 状态资源目录路径
@export var status_resource_dir: String = "res://data/ability_status/"
## 状态资源文件后缀（不包含扩展名）
@export var status_resource_suffix: String = "_status"

@export_group("Debug Controls")
## 切换面板显示的快捷键（使用 Input Map 中的 action 名称）
@export var toggle_action: String = "toggle_status_debug"

# 实体数据 {entity_name: {node: Node, component: GameplayStatusComponent}}
var _entities: Dictionary = {}
var _selected_entity: Node = null
var _selected_component: GameplayStatusComponent = null

# 状态图标缓存 {status_id: StatusIcon}
var _status_icons: Dictionary = {}

func _ready() -> void:
	# 连接信号
	entity_list.item_selected.connect(_on_entity_selected)
	add_status_button.pressed.connect(_on_add_status_pressed)
	remove_status_button.pressed.connect(_on_remove_status_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)

	# 初始隐藏面板（调试面板默认隐藏）
	visible = false

	# 初始扫描
	_scan_entities()

## 处理未处理的输入事件（用于快捷键）
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle_visibility()
		get_viewport().set_input_as_handled()

## 切换面板显示/隐藏
func toggle_visibility() -> void:
	visible = not visible
	if visible:
		# 显示时刷新实体列表
		_scan_entities()

## 扫描场景中所有包含 GameplayStatusComponent 的实体
## 使用 Group 机制，更高效
func _scan_entities() -> void:
	_entities.clear()
	entity_list.clear()

	# 使用 Group 机制获取所有状态实体
	var entities = get_tree().get_nodes_in_group(ENTITY_GROUP)
	
	# 遍历实体，查找对应的 GameplayStatusComponent
	for entity in entities:
		if not is_instance_valid(entity):
			continue

		# 获取状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(entity, "GameplayStatusComponent")
		if not is_instance_valid(status_comp) or not status_comp is GameplayStatusComponent:
			continue
			
		# 生成实体名称
		var entity_name = entity.name if entity.name != "" else str(entity.get_path())
		# 如果名称重复，添加路径信息
		if _entities.has(entity_name):
			entity_name = str(entity.get_path())

		_entities[entity_name] = {
			"node": entity,
			"component": status_comp as GameplayStatusComponent
		}

	# 更新列表显示
	for entity_name in _entities.keys():
		var entity_data = _entities[entity_name]
		var display_name = "%s (%s)" % [entity_name, entity_data.node.get_class()]
		entity_list.add_item(display_name)

## 更新状态显示
func _update_status_display() -> void:
	# 清除旧的状态图标
	for icon in _status_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_status_icons.clear()

	if not is_instance_valid(_selected_component):
		return

	# 获取所有激活的状态
	var active_statuses = _selected_component.get_active_statuses()
	# 为每个状态创建图标
	for status_instance in active_statuses:
		if not is_instance_valid(status_instance) or not is_instance_valid(status_instance.status_data):
			continue
		# 创建状态图标
		var icon_container = _create_status_icon(status_instance)
		status_container.add_child(icon_container)

## 创建状态图标
func _create_status_icon(status_instance: GameplayStatusInstance) -> Control:
	if not is_instance_valid(status_instance) or not is_instance_valid(status_instance.status_data):
		return null

	var status_data = status_instance.status_data
	var status_id = status_data.status_id

	# 实例化状态图标场景
	var icon : StatusIcon = STATUS_ICON_PREFAB.instantiate()
	if not is_instance_valid(icon):
		push_warning("StatusDebugPanel: Failed to instantiate status icon")
		return null

	# 设置状态实例
	icon.setup(status_instance)
	_status_icons[status_id] = icon
	return icon

## 加载状态资源
## 尝试从配置的目录加载状态资源
func _load_status_resource(status_id: StringName) -> GameplayStatusData:
	# 确保路径以 / 结尾
	var dir_path = status_resource_dir
	if not dir_path.ends_with("/"):
		dir_path += "/"

	# 方法1: 尝试直接加载资源文件（使用配置的后缀）
	var resource_path = "%s%s%s.tres" % [dir_path, status_id, status_resource_suffix]
	if ResourceLoader.exists(resource_path):
		var resource = load(resource_path) as GameplayStatusData
		if is_instance_valid(resource) and resource.status_id == status_id:
			return resource

	# 方法2: 扫描配置的目录
	var dir = DirAccess.open(dir_path)
	if is_instance_valid(dir):
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = dir_path + file_name
				var resource = load(full_path) as GameplayStatusData
				if is_instance_valid(resource) and resource.status_id == status_id:
					return resource
			file_name = dir.get_next()

	return null

## 实体选择回调
func _on_entity_selected(index: int) -> void:
	if index < 0 or index >= _entities.size():
		return
		
	# 断开旧组件的信号连接
	if is_instance_valid(_selected_component):
		if _selected_component.status_applied.is_connected(_on_status_applied):
			_selected_component.status_applied.disconnect(_on_status_applied)
		if _selected_component.status_removed.is_connected(_on_status_removed):
			_selected_component.status_removed.disconnect(_on_status_removed)
		if _selected_component.status_stacked.is_connected(_on_status_stacked):
			_selected_component.status_stacked.disconnect(_on_status_stacked)

	var entity_name = _entities.keys()[index]
	var entity_data = _entities[entity_name]

	_selected_entity = entity_data.node
	_selected_component = entity_data.component

	# 连接新组件的信号
	if is_instance_valid(_selected_component):
		if not _selected_component.status_applied.is_connected(_on_status_applied):
			_selected_component.status_applied.connect(_on_status_applied)
		if not _selected_component.status_removed.is_connected(_on_status_removed):
			_selected_component.status_removed.connect(_on_status_removed)
		if not _selected_component.status_stacked.is_connected(_on_status_stacked):
			_selected_component.status_stacked.connect(_on_status_stacked)

	# 更新状态显示
	_update_status_display()

## 状态应用回调
func _on_status_applied(_status_id: StringName, _instance: GameplayStatusInstance) -> void:
	_update_status_display()

## 状态移除回调
func _on_status_removed(_status_id: StringName) -> void:
	_update_status_display()

## 状态堆叠回调
func _on_status_stacked(_status_id: StringName, _new_stacks: int) -> void:
	# 更新对应图标的层数显示
	if _status_icons.has(_status_id):
		var icon = _status_icons[_status_id]
		if is_instance_valid(icon):
			icon.update_stack_display()

## 添加状态
func _on_add_status_pressed() -> void:
	if not is_instance_valid(_selected_component):
		push_warning("StatusDebugPanel: No entity selected")
		return
		
	var status_id_str = status_id_input.text.strip_edges()
	if status_id_str.is_empty():
		push_warning("StatusDebugPanel: Status ID is empty")
		return
	
	var status_id = StringName(status_id_str)
	# 尝试加载状态资源
	var status_data = _load_status_resource(status_id)
	if not is_instance_valid(status_data):
		push_warning("StatusDebugPanel: Failed to load status resource: %s" % status_id_str)
		return
	
	# 应用状态
	var player = get_tree().get_first_node_in_group("Player")
	var facing_angle : float = _selected_entity.get_facing_angle() if _selected_entity.has_method("get_facing_angle") else 0.0
	var context : Dictionary = {
		"facing_angle": facing_angle
	}
	_selected_component.apply_status(status_data, player, 1, context)
	
	# 更新显示
	_update_status_display()

	# 清空输入框
	status_id_input.text = ""

## 移除状态
func _on_remove_status_pressed() -> void:
	if not is_instance_valid(_selected_component):
		push_warning("StatusDebugPanel: No entity selected")
		return

	var status_id_str = status_id_input.text.strip_edges()
	if status_id_str.is_empty():
		push_warning("StatusDebugPanel: Status ID is empty")
		return
	
	var status_id = StringName(status_id_str)
	# 移除状态
	_selected_component.remove_status(status_id)

	# 更新显示
	_update_status_display()
	
	# 清空输入框
	status_id_input.text = ""

## 刷新实体列表
func _on_refresh_pressed() -> void:
	_scan_entities()
	if is_instance_valid(_selected_entity):
		# 尝试重新选择当前实体
		for i in range(entity_list.item_count):
			var item_text = entity_list.get_item_text(i)
			if _selected_entity.name in item_text or str(_selected_entity.get_path()) in item_text:
				entity_list.select(i)
				_on_entity_selected(i)
				break
