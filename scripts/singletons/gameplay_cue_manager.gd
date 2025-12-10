extends Node

## 游戏提示管理器（单例）
## 负责执行 Cue，处理所有表现相关的脏活累活
## 核心思想：Fire and Forget（射后不理）
## 采用组合模式，将具体表现处理交给 Cue 组件

## 飘字场景模板（用于初始化飘字 Cue 的对象池）
var _floating_text_template: PackedScene = null
## 持续 Cue 列表（需要每帧更新的 Cue，如拖尾）
var _persistent_cues: Array[GameplayCueBase] = []

func _ready() -> void:
	# 初始化飘字模板
	_init_floating_text_template()
	# 启用 process 以更新持续 Cue
	set_process(true)

func _process(delta: float) -> void:
	# 更新所有持续 Cue（如拖尾残影）
	var to_remove: Array[GameplayCueBase] = []
	for cue_component in _persistent_cues:
		if not is_instance_valid(cue_component):
			to_remove.append(cue_component)
			continue
		
		# 如果 Cue 组件实现了 _process_trails 方法，调用它
		if cue_component.has_method("_process_trails"):
			cue_component._process_trails(delta)
	
	# 清理无效的 Cue
	for cue_component in to_remove:
		_persistent_cues.erase(cue_component)

## 初始化飘字模板
func _init_floating_text_template() -> void:
	_floating_text_template = load("res://prefabs/fx/floating_text.tscn")
	if not is_instance_valid(_floating_text_template):
		push_warning("GameplayCueManager: Floating text scene not found")

## 执行 Cue（核心接口）
## [param] cue: GameplayCue Cue 资源
## [param] target: Node 目标节点（用于计算挂点位置）
## [param] context: Dictionary 上下文信息（可选，如伤害值、治疗值等）
func execute_cue(cue: GameplayCue, target: Node, context: Dictionary = {}) -> void:
	if not is_instance_valid(cue):
		return
	
	# 遍历所有 Cue 组件并执行
	for cue_component in cue.cues:
		if not is_instance_valid(cue_component):
			continue
		
		# 计算挂点位置（使用 AttachmentPointUtils 工具类）
		var location = _get_attachment_point_position(target, cue_component.attachment_point)
		
		# 应用偏移量（如果配置了）
		location += cue_component.offset
		
		# 初始化飘字 Cue 的对象池（如果需要）
		if cue_component.has_method("initialize_pool"):
			if cue_component.get("_text_template") == null and is_instance_valid(_floating_text_template):
				cue_component.initialize_pool(_floating_text_template, 10)
		
		# 执行 Cue 组件
		cue_component.execute(target, location, context)
		
		# 如果是持续 Cue（需要每帧更新），添加到列表
		if cue_component.has_method("_process_trails") and not _persistent_cues.has(cue_component):
			_persistent_cues.append(cue_component)

## 获取挂点位置（使用 AttachmentPointUtils 工具类）
## [param] target: Node 目标节点
## [param] attachment_point: StringName 挂点名（如 "head", "foot", "weapon" 等）
## [return] Vector3 挂点位置（世界坐标）
func _get_attachment_point_position(target: Node, attachment_point: StringName) -> Vector3:
	# 使用 AttachmentPointUtils 工具类（统一挂点查找逻辑）
	return AttachmentPointUtils.get_attachment_point_position(target, attachment_point)
