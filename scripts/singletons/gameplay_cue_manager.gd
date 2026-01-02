extends Node

## 游戏提示管理器（单例）
## 负责执行 Cue，处理所有表现相关的脏活累活
## 采用组合模式，将具体表现处理交给 Cue 组件

## 持续 Cue 列表（需要每帧更新的 Cue，如拖尾）
var _persistent_cues: Array[GameplayCueBase] = []

func _process(delta: float) -> void:
	# 更新所有持续 Cue（如拖尾残影）
	var to_remove: Array[GameplayCueBase] = []
	for cue_component : GameplayCueBase in _persistent_cues:
		if not is_instance_valid(cue_component):
			to_remove.append(cue_component)
			continue
		# 如果 Cue 组件实现了 upadte 方法，调用它
		cue_component.update(delta)
	
	for cue_component in to_remove:
		_persistent_cues.erase(cue_component)

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

		# 执行 Cue 组件
		cue_component.execute(target, location, context)
		
		_persistent_cues.append(cue_component)

func stop_cue(cue: GameplayCue, target: Node, context: Dictionary = {}) -> void:
	if not is_instance_valid(cue):
		# 如果没有保存的 Cue 实例，说明可能没有执行过 Cue，直接返回
		return
	
	# 【关键】使用克隆的 Cue 实例停止持续效果
	# 遍历所有 Cue 组件并停止持续效果
	for cue_component in cue.cues:
		if not is_instance_valid(cue_component):
			continue

		cue_component.stop(target)
		if _persistent_cues.has(cue_component):
			_persistent_cues.erase(cue_component)

## 获取挂点位置（使用 AttachmentPointUtils 工具类）
## [param] target: Node 目标节点
## [param] attachment_point: StringName 挂点名（如 "head", "foot", "weapon" 等）
## [return] Vector3 挂点位置（世界坐标）
func _get_attachment_point_position(target: Node, attachment_point: StringName) -> Vector3:
	if not is_instance_valid(target):
		return Vector3.INF
	
	# 如果目标实现了 get_attachment_point 方法，直接调用
	if target.has_method("get_attachment_point"):
		var point = target.get_attachment_point(attachment_point)
		if is_instance_valid(point) and point is Node3D:
			return (point as Node3D).global_position
	else:
		push_warning("target dont has method get_attachment_point!")

	return Vector3.INF
