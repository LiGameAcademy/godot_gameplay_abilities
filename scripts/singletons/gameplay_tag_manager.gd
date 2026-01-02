extends Node

## 标签管理器（单例）
## 管理所有游戏标签的生命周期和查询

## Meta 数据前缀，防止冲突
const META_PREFIX: String = "tag_ref_"
## Groups 命名空间前缀（避免污染）
## 所有标签组都会使用此前缀，确保不会与游戏逻辑的 Groups 冲突
const TAG_GROUP_PREFIX: String = "tag_"

## 数据库：存储所有加载的标签资源 (ID -> Resource)
var _tag_db: Dictionary[StringName, GameplayTag] = {}
## 是否已初始化
var _initialized: bool = false
## 标签继承关系缓存 (tag_id -> Array[parent_tag_ids])
var _tag_inheritance_cache: Dictionary[StringName, Array] = {}
## 标签互斥关系缓存 (tag_id -> Array[mutually_exclusive_tag_ids])
var _tag_exclusion_cache: Dictionary[StringName, Array] = {}
## 查询缓存 (target_id -> {tag_id -> bool})
## 用于缓存频繁查询的结果，提高性能
var _query_cache: Dictionary[int, Dictionary] = {}
var _cache_enabled: bool = true  ## 是否启用查询缓存

## 标签添加信号
signal tag_added(target: Node, tag_id: StringName)
## 标签移除信号
signal tag_removed(target: Node, tag_id: StringName)

func initialize(tag_or_tags : Variant, recursive: bool = true) -> void:
	if _initialized:
		push_warning("已经初始化！")
	_initialized = true
	if tag_or_tags is GameplayTag:
		register_tag(tag_or_tags)
	elif tag_or_tags is Array[GameplayTag]:
		register_tags(tag_or_tags)
	elif tag_or_tags is String:
		register_tags_from_directory(tag_or_tags, recursive)

## 注册单个标签资源
## [param] tag: GameplayTag 标签资源
## [returns] bool 是否注册成功
func register_tag(tag: GameplayTag) -> bool:
	if not is_instance_valid(tag):
		push_warning("TagManager: Cannot register invalid tag resource")
		return false

	if tag.id.is_empty():
		push_warning("TagManager: Cannot register tag with empty ID")
		return false
	
	if _tag_db.has(tag.id):
		push_warning("TagManager: Tag [%s] is already registered" % tag.id)
		return false

	_tag_db[tag.id] = tag
	print("TagManager: Registered tag [%s]" % tag.id)

	# 如果已初始化，需要重建关系缓存
	if _initialized:
		_build_tag_relation_caches()

	return true

## 注册多个标签资源
## [param] tags: Array[GameplayTag] 标签资源数组
## [returns] int 成功注册的数量
func register_tags(tags: Array[GameplayTag]) -> int:
	var count = 0
	for tag in tags:
		if register_tag(tag):
			count += 1
	return count

## 从目录扫描并注册所有标签资源
## [param] dir_path: String 标签资源目录路径（支持 res:// 路径）
## [param] recursive: bool 是否递归扫描子目录（默认 true）
## [returns] int 成功注册的数量
func register_tags_from_directory(dir_path: String, recursive: bool = true) -> int:
	# 确保路径以 / 结尾
	if not dir_path.ends_with("/"):
		dir_path += "/"

	var dir = DirAccess.open(dir_path)
	if not is_instance_valid(dir):
		push_warning("TagManager: Cannot open tag directory: %s" % dir_path)
		return 0

	var error = dir.list_dir_begin()
	if error != OK:
		push_warning("TagManager: Failed to list directory: %s (error: %d)" % [dir_path, error])
		return 0

	var count = 0
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with(".") and recursive:
			# 递归扫描子目录
			var sub_dir_path = dir_path.path_join(file_name)
			count += register_tags_from_directory(sub_dir_path, recursive)
		elif file_name.ends_with(".tres"):
			var full_path = dir_path.path_join(file_name)
			var resource = load(full_path) as GameplayTag
			if resource and resource.id != &"":
				if register_tag(resource):
					count += 1
			else:
				push_warning("TagManager: Invalid tag resource at %s" % full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	
	# 构建继承和互斥关系缓存
	if not _initialized:
		_build_tag_relation_caches()
		_initialized = true
		print("TagManager: Initialized with %d tags" % _tag_db.size())
		
	return count

## 注销标签资源
## [param] tag_id: StringName 标签ID
## [returns] bool 是否注销成功
func unregister_tag(tag_id: StringName) -> bool:
	if not _tag_db.has(tag_id):
		push_warning("TagManager: Tag [%s] is not registered" % tag_id)
		return false
	_tag_db.erase(tag_id)
	print("TagManager: Unregistered tag [%s]" % tag_id)
	# 重建关系缓存（因为可能有其他标签依赖此标签）
	if _initialized:
		_build_tag_relation_caches()
	return true

## 添加标签（引用计数 +1）
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
func add_tag(target: Node, tag_id: StringName) -> bool:
	if not is_instance_valid(target):
		push_warning("TagManager: Cannot add tag to invalid target")
		return false
	
	if not _validate_tag(tag_id):
		return false
	
	# 处理互斥标签：移除所有互斥标签
	var exclusions = get_tag_exclusions(tag_id)
	for excl_tag_id in exclusions:
		if has_tag(target, excl_tag_id):
			force_remove_tag(target, excl_tag_id)
	
	var key: String = _get_meta_key(tag_id)
	var count: int = target.get_meta(key, 0)
	
	count += 1
	target.set_meta(key, count)
	
	# 首次添加：加入 Godot 原生组（使用带前缀的组名）
	if count == 1:
		var group_name = _get_tag_group_name(tag_id)
		target.add_to_group(group_name)
		
		# 清除查询缓存（因为标签状态改变了）
		if _cache_enabled:
			clear_query_cache(target)
		
		# 触发标签添加事件
		tag_added.emit(target, tag_id)

	return true

## 移除标签（引用计数 -1）
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
func remove_tag(target: Node, tag_id: StringName) -> bool:
	if not is_instance_valid(target):
		push_warning("TagManager: Cannot remove tag from invalid target")
		return false
	
	if not _validate_tag(tag_id):
		return false
		
	var key: String = _get_meta_key(tag_id)
	var count: int = target.get_meta(key, 0)
	
	if count < 0:
		return false
		
	count -= 1
	target.set_meta(key, count)
	
	# 归零：从 Godot 原生组移除（使用带前缀的组名）
	if count <= 0:
		var group_name = _get_tag_group_name(tag_id)
		target.remove_from_group(group_name)
		target.remove_meta(key)  # 清理内存

		# 清除查询缓存（因为标签状态改变了）
		if _cache_enabled:
			clear_query_cache(target)

		# 触发标签移除事件
		tag_removed.emit(target, tag_id)

	return true

## 强制移除标签（忽略引用计数，直接移除）
## 用于清理或重置状态
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
func force_remove_tag(target: Node, tag_id: StringName) -> void:
	if not is_instance_valid(target):
		return
	if not _validate_tag(tag_id):
		return

	var key: String = _get_meta_key(tag_id)
	if target.has_meta(key):
		var group_name = _get_tag_group_name(tag_id)
		target.remove_from_group(group_name)
		target.remove_meta(key)

		# 清除查询缓存
		if _cache_enabled:
			clear_query_cache(target)

		tag_removed.emit(target, tag_id)

## 清除目标的所有标签
## [param] target: Node 目标节点
func clear_all_tags(target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	# 获取所有标签组（只处理带前缀的组）
	var groups = target.get_groups()
	var tags_to_remove: Array[StringName] = []
	
	for group in groups:
		if _is_tag_group(group):
			var tag_id = _extract_tag_id_from_group(group)
			if tag_id != &"" and target.has_meta(_get_meta_key(tag_id)):
				tags_to_remove.append(tag_id)
	# 批量移除
	for tag_id in tags_to_remove:
		force_remove_tag(target, tag_id)

	# 清除查询缓存
	if _cache_enabled:
		clear_query_cache(target)

## 批量添加标签
## [param] target: Node 目标节点
## [param] tag_ids: Array[StringName] 标签ID列表
func add_tags(target: Node, tag_ids: Array[StringName]) -> void:
	for tag_id in tag_ids:
		add_tag(target, tag_id)

## 批量移除标签
## [param] target: Node 目标节点
## [param] tag_ids: Array[StringName] 标签ID列表
func remove_tags(target: Node, tag_ids: Array[StringName]) -> void:
	for tag_id in tag_ids:
		remove_tag(target, tag_id)

## 清除查询缓存（针对特定目标或全部）
## [param] target: Node 目标节点（如果为 null，清除所有缓存）
func clear_query_cache(target: Node = null) -> void:
	if not is_instance_valid(target):
		_query_cache.clear()
	else:
		var target_id = target.get_instance_id()
		_query_cache.erase(target_id)

## 检查是否有特定标签 (O(1) 复杂度，支持继承查询)
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
## [param] include_inherited: bool 是否包含继承的标签（默认 true）
## [returns] bool 是否有该标签
func has_tag(target: Node, tag_id: StringName, include_inherited: bool = true) -> bool:
	if not is_instance_valid(target):
		return false

	# 计算缓存键（需要在函数作用域内定义）
	var cache_key: String = tag_id if include_inherited else (tag_id as String + "_direct")

	if _cache_enabled:
		var target_id = target.get_instance_id()
		if _query_cache.has(target_id) and _query_cache[target_id].has(cache_key):
			return _query_cache[target_id][cache_key]

	var group_name = _get_tag_group_name(tag_id)
	var has_direct = target.is_in_group(group_name)

	# 如果直接拥有，返回 true
	if has_direct:
		if _cache_enabled:
			var target_id = target.get_instance_id()
			if not _query_cache.has(target_id):
				_query_cache[target_id] = {}
			_query_cache[target_id][cache_key] = true

		return true
		
	# 如果包含继承查询，检查子标签（目标拥有的标签是否继承自查询的标签）
	# 例如：查询 status.debuff，如果目标有 status.burn（继承自 status.debuff），应该返回 true
	if include_inherited:
		# 获取目标的所有标签
		var target_tags = get_all_tags(target)
		# 对于每个目标标签，检查它是否继承自查询的标签
		for target_tag_id in target_tags:
			if tag_inherits_from(target_tag_id, tag_id):
				# 缓存结果
				if _cache_enabled:
					var target_id = target.get_instance_id()
					if not _query_cache.has(target_id):
						_query_cache[target_id] = {}
					_query_cache[target_id][cache_key] = true
				return true

	# 缓存结果
	if _cache_enabled:
		var target_id = target.get_instance_id()
		if not _query_cache.has(target_id):
			_query_cache[target_id] = {}
		_query_cache[target_id][cache_key] = false
	return false

## 检查是否有列表中的任意标签（用于互斥/免疫检查，支持继承查询）
func has_any_tag(target: Node, tag_list: Array[StringName], include_inherited: bool = true) -> bool:
	if not is_instance_valid(target):
		return false
	
	return tag_list.any(
		func(tag: StringName) -> bool:
			return has_tag(target, tag, include_inherited)
	)

## 检查是否有列表中的所有标签（支持继承查询）
## [param] target: Node 目标节点
## [param] tag_list: Array[StringName] 标签ID列表
## [param] include_inherited: bool 是否包含继承的标签（默认 true）
## [returns] bool 是否有所有标签
func has_all_tags(target: Node, tag_list: Array[StringName], include_inherited: bool = true) -> bool:
	if not is_instance_valid(target):
		return false
	
	return tag_list.all(
		func(tag: StringName) -> bool:
			return has_tag(target, tag, include_inherited)
	)

## 获取标签的引用计数
## [param] target: Node 目标节点
## [param] tag_id: StringName 标签ID
## [returns] int 引用计数
func get_tag_count(target: Node, tag_id: StringName) -> int:
	if not is_instance_valid(target):
		return 0
	var key: String = _get_meta_key(tag_id)
	return target.get_meta(key, 0)

## 获取目标的所有标签ID列表（只返回直接标签，不包括继承）
## [param] target: Node 目标节点
## [returns] Array[StringName] 标签ID列表
func get_all_tags(target: Node) -> Array[StringName]:
	if not is_instance_valid(target):
		return []
	var result: Array[StringName] = []
	var groups = target.get_groups()
	for group in groups:
		if _is_tag_group(group):
			var tag_id = _extract_tag_id_from_group(group)
			if tag_id != &"":
				var key: String = _get_meta_key(tag_id)
				if target.has_meta(key):
					result.append(tag_id)
	return result

## 获取标签的完整继承链（包括自身）
## [param] tag_id: StringName 标签ID
## [returns] Array[StringName] 继承链（从自身到根）
func get_tag_inheritance_chain(tag_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = [tag_id]
	var parent_chain = _tag_inheritance_cache.get(tag_id, [])
	result.append_array(parent_chain)
	return result

## 获取标签的所有互斥标签
## [param] tag_id: StringName 标签ID
## [returns] Array[StringName] 互斥标签列表
func get_tag_exclusions(tag_id: StringName) -> Array[StringName]:
	return _tag_exclusion_cache.get(tag_id, [] as Array[StringName]).duplicate()

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

## 验证标签资源（运行时验证）
## [param] tag_id: StringName 标签ID
## [returns] bool 是否有效
func validate_tag(tag_id: StringName) -> bool:
	if tag_id == &"":
		push_warning("TagManager: Tag ID is empty")
		return false
	
	if not _tag_db.has(tag_id):
		push_warning("TagManager: Tag [%s] not found in database" % tag_id)
		return false
		
	var tag = _tag_db[tag_id]
	if not is_instance_valid(tag):
		push_warning("TagManager: Tag resource [%s] is not valid" % tag_id)
		return false
		
	# 验证父标签是否存在
	if tag.parent_tag_id != &"":
		if not _tag_db.has(tag.parent_tag_id):
			push_warning("TagManager: Tag [%s] has invalid parent tag [%s]" % [tag_id, tag.parent_tag_id])
			return false

	# 验证互斥标签是否存在
	for excl_tag_id in tag.mutually_exclusive_tags:
		if not _tag_db.has(excl_tag_id):
			push_warning("TagManager: Tag [%s] has invalid mutually exclusive tag [%s]" % [tag_id, excl_tag_id])
			return false
	return true

## 验证标签ID列表（用于验证技能/状态/效果的标签配置）
## [param] tag_ids: Array[StringName] 标签ID列表
## [returns] bool 是否全部有效
func validate_tag_list(tag_ids: Array[StringName]) -> bool:
	for tag_id in tag_ids:
		if not validate_tag(tag_id):
			return false
	return true

## 检查标签是否继承自指定父标签
## [param] tag_id: StringName 标签ID
## [param] parent_tag_id: StringName 父标签ID
## [returns] bool 是否继承
func tag_inherits_from(tag_id: StringName, parent_tag_id: StringName) -> bool:
	if tag_id == parent_tag_id:
		return true
	var inheritance_chain = get_tag_inheritance_chain(tag_id)
	return inheritance_chain.has(parent_tag_id)

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

## 构建标签关系缓存（继承和互斥）
func _build_tag_relation_caches() -> void:
	_tag_inheritance_cache.clear()
	_tag_exclusion_cache.clear()

	# 构建继承关系缓存
	for tag_id in _tag_db:
		var tag := _tag_db[tag_id]
		var parent_chain: Array[StringName] = []
		var current_tag_id = tag_id

		# 递归查找所有父标签
		while true:
			var current_tag = _tag_db.get(current_tag_id)
			if not is_instance_valid(current_tag) or current_tag.parent_tag_id == &"":
				break
			var parent_id = current_tag.parent_tag_id
			if not _tag_db.has(parent_id):
				push_warning("TagManager: Parent tag [%s] not found for tag [%s]" % [parent_id, current_tag_id])
				break
			parent_chain.append(parent_id)
			current_tag_id = parent_id
			
		_tag_inheritance_cache[tag_id] = parent_chain

	# 构建互斥关系缓存（包括继承的互斥）
	for tag_id in _tag_db:
		var tag := _tag_db[tag_id]
		var exclusion_set: Array[StringName] = []

		# 添加直接互斥标签
		for excl_tag_id in tag.mutually_exclusive_tags:
			if _tag_db.has(excl_tag_id):
				exclusion_set.append(excl_tag_id)

		# 添加父标签的互斥标签（继承互斥关系）
		var parent_chain = _tag_inheritance_cache.get(tag_id, [])
		for parent_id in parent_chain:
			var parent_tag = _tag_db.get(parent_id)
			if is_instance_valid(parent_tag):
				for excl_tag_id in parent_tag.mutually_exclusive_tags:
					if _tag_db.has(excl_tag_id) and not exclusion_set.has(excl_tag_id):
						exclusion_set.append(excl_tag_id)

		_tag_exclusion_cache[tag_id] = exclusion_set

## 验证标签是否已注册
## [param] tag_id: StringName 标签ID
## [returns] bool 是否有效
func _validate_tag(tag_id: StringName) -> bool:
	if not _tag_db.has(tag_id):
		push_warning("TagManager: Tag [%s] not found in database" % tag_id)
		return false
	return true

## 获取标签的元数据键名（将点号替换为下划线，确保是有效的标识符）
## [param] tag_id: StringName 标签ID
## [returns] String 元数据键名
func _get_meta_key(tag_id: StringName) -> String:
	# 将点号替换为下划线，确保是有效的 ASCII 标识符
	var safe_id = str(tag_id).replace(".", "_")
	return META_PREFIX + safe_id

## 获取标签的 Groups 名称（带前缀，避免污染）
## [param] group_name: String Groups 名称
## [returns] bool 是否为标签组
func _get_tag_group_name(tag_id: StringName) -> String:
	return TAG_GROUP_PREFIX + str(tag_id)

## 验证 Groups 是否为标签组
## [param] group_name: String Groups 名称
## [returns] bool 是否为标签组
func _is_tag_group(group_name: String) -> bool:
	return group_name.begins_with(TAG_GROUP_PREFIX)

## 从 Groups 名称提取标签ID
## [param] group_name: String Groups 名称
## [returns] StringName 标签ID，如果不是标签组则返回空
func _extract_tag_id_from_group(group_name: String) -> StringName:
	if not _is_tag_group(group_name):
		return &""
	return group_name.substr(TAG_GROUP_PREFIX.length()) as StringName
