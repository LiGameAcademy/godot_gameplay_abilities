extends MarginContainer
class_name AttributeDashboard

## 属性面板
## 显示和管理角色的属性系统

# 配置：哪些是一级，哪些是二级
const PRIMARY_ATTRS = [&"strength", &"agility", &"intelligence", &"vitality"]
const SECONDARY_ATTRS = [&"health", &"mana", &"attack", &"defense", &"speed", &"crit_rate"]

# UI 节点引用
@onready var header_container = %HeaderContainer
@onready var points_label = %PointsLabel
@onready var primary_section = %PrimarySection
@onready var primary_container = %PrimaryContainer
@onready var secondary_section = %SecondarySection
@onready var secondary_container = %SecondaryContainer

# 预制体
@export var row_prefab: PackedScene

var _points_manager: AttributePointsManager
var _attribute_component: GameplayAttributeComponent

# 缓存 UI 行实例 { attr_id: AttributeRow }
var _rows: Dictionary = {}

func _ready() -> void:
	var player : Player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		push_error("Player not found")
		return
	
	var attribute_comp : GameplayAttributeComponent = GameplayAbilitySystem.get_component_by_interface(player, "GameplayAttributeComponent")
	if not is_instance_valid(attribute_comp):
		push_error("Attribute component not found")
		return
	
	initialize(attribute_comp, player.attribute_points_manager)

## 初始化面板
## [param] comp: GameplayAttributeComponent 属性组件
## [param] points_mgr: AttributePointsManager 点数管理器
func initialize(comp: GameplayAttributeComponent, points_mgr: AttributePointsManager = null) -> void:
	_attribute_component = comp
	_points_manager = points_mgr
	
	# 如果没有提供点数管理器，创建一个默认的
	if not _points_manager:
		_points_manager = AttributePointsManager.new(0)
	
	# 1. 监听属性变化信号
	_attribute_component.attribute_value_changed.connect(_on_attribute_changed)
	
	# 2. 监听点数变化信号
	_points_manager.points_changed.connect(_on_points_changed)
	
	# 3. 生成一级属性 UI (可分配点数)
	for id in PRIMARY_ATTRS:
		_create_row(id, primary_container, true)
		
	# 4. 生成二级属性 UI (只读显示)
	for id in SECONDARY_ATTRS:
		_create_row(id, secondary_container, false)
		
	# 5. 初始化点数显示
	_update_points_display()

## 创建属性行
## [param] attr_id: StringName 属性ID
## [param] parent: Node 父容器
## [param] allow_add: bool 是否允许加点
func _create_row(attr_id: StringName, parent: Node, allow_add: bool) -> void:
	var attr_instance = _attribute_component.get_attribute(attr_id)
	if not attr_instance:
		push_warning("Attribute [%s] not found" % attr_id)
		return
	
	var attr_res = attr_instance.attribute_def
	if not attr_res:
		push_warning("Attribute resource for [%s] not found" % attr_id)
		return
	
	var row = row_prefab.instantiate()
	parent.add_child(row)
	row.setup(_attribute_component, attr_res, allow_add)
	
	# 连接加点请求
	if allow_add and not row.increase_requested.is_connected(_on_increase_requested):
		row.increase_requested.connect(_on_increase_requested)
	
	_rows[attr_id] = row

## 处理加点请求
## [param] attr_id: StringName 要加点的属性ID
func _on_increase_requested(attr_id: StringName):
	# 1. 检查是否有足够的点数
	if not _points_manager.has_sufficient_points(1):
		_show_message("点数不足！")
		return
	
	# 2. 检查属性是否存在
	if not _attribute_component.has_attribute(attr_id):
		_show_message("属性不存在！")
		return
	
	# 3. 执行加点事务
	if _points_manager.try_spend_points(1):
		# 增加属性基础值
		var current_base = _attribute_component.get_attribute(attr_id).base_value
		_attribute_component.set_base_value(attr_id, current_base + 1.0)
		
		# 注意：属性变化会自动触发信号，UI会自动更新
		# 二级属性的变化也会自动通过依赖系统更新

## 属性值变化回调
## [param] attr_id: StringName 变化的属性ID
## [param] new_val: float 新值
func _on_attribute_changed(attr_id: StringName, new_val: float) -> void:
	if _rows.has(attr_id):
		_rows[attr_id].update_display(new_val)

## 点数变化回调
## [param] _new_points: int 新的点数
func _on_points_changed(_new_points: int):
	_update_points_display()

## 更新点数显示
func _update_points_display() -> void:
	if points_label:
		points_label.text = "可用点数: %d" % _points_manager.available_points

## 显示消息（可扩展为Toast提示）
## [param] message: String 消息内容
func _show_message(message: String) -> void:
	print(message)  # 可以替换为Toast UI
