extends Node

## 标签管理器（单例）
## 管理所有游戏标签的生命周期和查询

#region ========== 常量 ==========

## Meta 数据前缀，防止冲突
const META_PREFIX: String = "tag_ref_"

## 默认标签资源目录
const DEFAULT_TAG_DIR: String = "res://data/tags/"

#endregion

#region ========== 私有变量 ==========

## 数据库：存储所有加载的标签资源 (ID -> Resource)
var _tag_db: Dictionary[StringName, GameplayTag] = {}

## 是否已初始化
var _initialized: bool = false

#endregion

#region ========== 信号 ==========

## 标签添加信号
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
signal tag_added(target: Node, tag_id: StringName)

## 标签移除信号
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
signal tag_removed(target: Node, tag_id: StringName)

#endregion

func _ready() -> void:
	# 初始化时加载所有标签资源
	_scan_and_load_tags(DEFAULT_TAG_DIR)

#region ========== 初始化 ==========

## 扫描并加载标签资源
## [param] dir_path: String 标签资源目录路径
func _scan_and_load_tags(dir_path: String) -> void:
	if _initialized:
		return
	
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_warning("TagManager: Cannot open tag directory: %s (will try to create it)" % dir_path)
		# 尝试创建目录（如果不存在）
		DirAccess.make_dir_recursive_absolute(dir_path)
		dir = DirAccess.open(dir_path)
		if not dir:
			push_warning("TagManager: Failed to create tag directory: %s" % dir_path)
			_initialized = true
			return
	
	var error = dir.list_dir_begin()
	if error != OK:
		push_warning("TagManager: Failed to list directory: %s (error: %d)" % [dir_path, error])
		_initialized = true
		return
	
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			# 递归扫描子目录
			_scan_and_load_tags(dir_path.path_join(file_name))
		elif file_name.ends_with(".tres"):
			var full_path = dir_path.path_join(file_name)
			var resource = load(full_path) as GameplayTag
			if resource and resource.id != &"":
				if _tag_db.has(resource.id):
					push_warning("TagManager: Duplicate tag ID [%s] found at %s (already exists)" % [resource.id, full_path])
				else:
					_tag_db[resource.id] = resource
					print("TagManager: Loaded tag [%s] from %s" % [resource.id, full_path])
			else:
				push_warning("TagManager: Invalid tag resource at %s" % full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	_initialized = true
	print("TagManager: Initialized with %d tags" % _tag_db.size())

#endregion

#region ========== API: 状态管理 ==========

## 添加标签（引用计数 +1）
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
func add_tag(target: Node, tag_id: StringName) -> void:
	if not is_instance_valid(target):
		push_warning("TagManager: Cannot add tag to invalid target")
		return
	
	if not _tag_db.has(tag_id):
		push_warning("TagManager: Tag [%s] not found in database" % tag_id)
		return
	
	var key: String = META_PREFIX + str(tag_id)
	var count: int = target.get_meta(key, 0)
	
	count += 1
	target.set_meta(key, count)
	
	# 首次添加：加入 Godot 原生组
	if count == 1:
		target.add_to_group(tag_id)
		tag_added.emit(target, tag_id)

## 移除标签（引用计数 -1）
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
func remove_tag(target: Node, tag_id: StringName) -> void:
	if not is_instance_valid(target):
		push_warning("TagManager: Cannot remove tag from invalid target")
		return
	
	var key: String = META_PREFIX + str(tag_id)
	var count: int = target.get_meta(key, 0)
	
	if count > 0:
		count -= 1
		target.set_meta(key, count)
		
		# 归零：从 Godot 原生组移除
		if count == 0:
			target.remove_from_group(tag_id)
			target.remove_meta(key) # 清理内存
			tag_removed.emit(target, tag_id)

## 强制移除标签（忽略引用计数，直接移除）
## 用于清理或重置状态
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
func force_remove_tag(target: Node, tag_id: StringName) -> void:
	if not is_instance_valid(target):
		return
	
	var key: String = META_PREFIX + str(tag_id)
	if target.has_meta(key):
		target.remove_from_group(tag_id)
		target.remove_meta(key)
		tag_removed.emit(target, tag_id)

## 清除目标的所有标签
## [param] target: Node 目标节点
func clear_all_tags(target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	# 获取所有标签组
	var groups = target.get_groups()
	for group in groups:
		var key: String = META_PREFIX + str(group)
		if target.has_meta(key):
			target.remove_from_group(group)
			target.remove_meta(key)
			tag_removed.emit(target, group)

#endregion

#region ========== API: 查询接口 ==========

## 检查是否有特定标签 (O(1) 复杂度)
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
## [returns] bool 是否有该标签
func has_tag(target: Node, tag_id: StringName) -> bool:
	if not is_instance_valid(target):
		return false
	return target.is_in_group(tag_id)

## 检查是否有列表中的任意标签（用于互斥/免疫检查）
## [param] target: Node 目标节点
## [param] tag_list: Array[StringName] 标签ID列表
## [returns] bool 是否有任意一个标签
func has_any_tag(target: Node, tag_list: Array[StringName]) -> bool:
	if not is_instance_valid(target):
		return false
	
	for tag in tag_list:
		if target.is_in_group(tag):
			return true
	
	return false

## 检查是否有列表中的所有标签
## [param] target: Node 目标节点
## [param] tag_list: Array[StringName] 标签ID列表
## [returns] bool 是否有所有标签
func has_all_tags(target: Node, tag_list: Array[StringName]) -> bool:
	if not is_instance_valid(target):
		return false
	
	for tag in tag_list:
		if not target.is_in_group(tag):
			return false
	
	return true

## 获取标签的引用计数
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
## [returns] int 引用计数
func get_tag_count(target: Node, tag_id: StringName) -> int:
	if not is_instance_valid(target):
		return 0
	
	var key: String = META_PREFIX + str(tag_id)
	return target.get_meta(key, 0)

## 获取目标的所有标签ID列表
## [param] target: Node 目标节点
## [returns] Array[StringName] 标签ID列表
func get_all_tags(target: Node) -> Array[StringName]:
	if not is_instance_valid(target):
		return []
	
	var result: Array[StringName] = []
	var groups = target.get_groups()
	
	for group in groups:
		var key: String = META_PREFIX + str(group)
		if target.has_meta(key):
			result.append(group)
	
	return result

#endregion

#region ========== API: 资源查询 ==========

## 获取标签的详细资源（用于 UI 渲染）
## [param] tag_id: StringName 标签ID
## [returns] GameplayTag 标签资源，如果不存在则返回 null
func get_tag_resource(tag_id: StringName) -> GameplayTag:
	return _tag_db.get(tag_id)

## 获取所有已注册的标签资源
## [returns] Dictionary[StringName, GameplayTag] 标签资源字典
func get_all_tag_resources() -> Dictionary[StringName, GameplayTag]:
	return _tag_db.duplicate()

## 检查标签是否已注册
## [param] tag_id: StringName 标签ID
## [returns] bool 是否已注册
func is_tag_registered(tag_id: StringName) -> bool:
	return _tag_db.has(tag_id)

#endregion

#region ========== 调试工具 ==========

## 打印目标的标签状态（用于调试）
## [param] target: Node 目标节点
func print_debug_status(target: Node) -> void:
	if not is_instance_valid(target):
		print("TagManager: Invalid target")
		return
	
	var tags = get_all_tags(target)
	print("TagManager: Debug status for [%s]:" % target.name)
	
	if tags.is_empty():
		print("  No tags")
		return
	
	for tag_id in tags:
		var count = get_tag_count(target, tag_id)
		var resource = get_tag_resource(tag_id)
		var display_name = resource.display_name if resource else "Unknown"
		print("  - [%s] (%s): count=%d" % [tag_id, display_name, count])

#endregion

