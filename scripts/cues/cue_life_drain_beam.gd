extends GameplayCueBase
class_name CueLifeDrainBeam

## 生命吸取牵引绳 Cue
## 在施法者和目标之间创建一条牵引绳，表示生命吸取效果
## 适用于引导类技能，需要持续更新位置

@export_group("Beam Settings")
## 牵引绳特效场景（.tscn）
@export var beam_scene: PackedScene = null
## 施法者挂点名（用于定位起点）
@export var instigator_attachment_point: StringName = &"body"
## 目标挂点名（用于定位终点）
@export var target_attachment_point: StringName = &"body"
## 是否允许重复创建（如果为 false，已有特效时不会重复创建）
@export var allow_duplicate: bool = false

## 存储已创建的特效实例（用于停止时清理）
## 格式：Dictionary[Node, Node] 目标节点 -> 特效节点
var _active_beams: Dictionary = {}  ## Dictionary[Node, Node3D]

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	# 1. 验证并获取施法者
	var instigator = context.get("instigator")
	if not is_instance_valid(instigator):
		push_warning("CueLifeDrainBeam: instigator is not valid in context")
		return
	
	# 2. 验证并实例化特效
	var beam = _validate_and_instantiate_beam()
	if not is_instance_valid(beam):
		return
	
	# 3. 检查是否允许重复创建
	if not _check_duplicate(target, beam):
		return
	
	# 4. 设置特效的起点和终点
	_setup_beam(beam, instigator, target, context)
	
	# 5. 将特效添加到场景树（添加到场景根节点，因为需要同时跟踪两个目标）
	var root = Engine.get_main_loop().root
	if is_instance_valid(root):
		root.add_child(beam)
	
	# 6. 如果特效场景实现了 setup_from_context 方法，传递上下文数据
	if beam.has_method("setup_from_context"):
		beam.setup_from_context(context)
	
	# 7. 记录特效实例（用于停止时清理）
	_active_beams[target] = beam
	
	# 8. 如果是持续 Cue（需要每帧更新），添加到持续 Cue 列表
	# 注意：CueManager 会自动处理持续 Cue 的更新
	# 通过 _process_trails 方法标记为持续 Cue

## 验证并实例化特效
## [return] Node3D 特效节点，如果失败则返回 null
func _validate_and_instantiate_beam() -> Node3D:
	if not is_instance_valid(beam_scene):
		push_warning("CueLifeDrainBeam: beam_scene is not valid")
		return null
	
	var beam = beam_scene.instantiate()
	if not is_instance_valid(beam):
		push_warning("CueLifeDrainBeam: Failed to instantiate beam scene")
		return null
	
	if not beam is Node3D:
		push_warning("CueLifeDrainBeam: beam_scene must instantiate a Node3D")
		beam.queue_free()
		return null
	
	return beam as Node3D

## 检查是否允许重复创建
## [param] target: Node 目标节点
## [param] beam: Node3D 特效节点
## [return] bool 如果允许创建返回 true，否则返回 false（并清理特效）
func _check_duplicate(target: Node, beam: Node3D) -> bool:
	if allow_duplicate:
		return true
	
	# 检查是否已经为这个目标创建了特效
	if _active_beams.has(target):
		var existing_beam = _active_beams[target]
		if is_instance_valid(existing_beam):
			# 已经有效果，不重复创建
			beam.queue_free()
			return false
	
	return true

## 设置特效的起点和终点
## [param] beam: Node3D 特效节点
## [param] instigator: Node 施法者节点
## [param] target: Node 目标节点
## [param] context: Dictionary 上下文信息
func _setup_beam(beam: Node3D, instigator: Node, target: Node, context: Dictionary) -> void:
	# 获取起点和终点位置
	var start_pos = _get_attachment_point_position(instigator, instigator_attachment_point)
	var end_pos = _get_attachment_point_position(target, target_attachment_point)
	
	# 如果特效节点实现了 set_start_and_end 方法，调用它
	if beam.has_method("set_start_and_end"):
		beam.set_start_and_end(start_pos, end_pos)
	else:
		# 否则，设置特效节点的位置为起点和终点的中点
		beam.global_position = (start_pos + end_pos) / 2.0
		
		# 如果特效节点有 start_point 和 end_point 属性，设置它们
		if beam.has("start_point"):
			beam.start_point = start_pos
		if beam.has("end_point"):
			beam.end_point = end_pos
	
	# 保存施法者和目标引用（用于持续更新）
	if beam.has("instigator"):
		beam.instigator = instigator
	if beam.has("target"):
		beam.target = target

## 获取挂点位置
## [param] node: Node 目标节点
## [param] attachment_point: StringName 挂点名
## [return] Vector3 挂点位置（世界坐标）
func _get_attachment_point_position(node: Node, attachment_point: StringName) -> Vector3:
	return AttachmentPointUtils.get_attachment_point_position(node, attachment_point)

## 持续更新（由 CueManager 每帧调用）
## 更新所有活跃的牵引绳位置
func _process_trails(delta: float) -> void:
	var to_remove: Array[Node] = []
	
	for target in _active_beams.keys():
		if not is_instance_valid(target):
			to_remove.append(target)
			continue
		
		var beam = _active_beams[target]
		if not is_instance_valid(beam):
			to_remove.append(target)
			continue
		
		# 获取施法者和目标
		var instigator = beam.get("instigator") if beam.has("instigator") else null
		if not is_instance_valid(instigator):
			to_remove.append(target)
			continue
		
		# 更新起点和终点位置
		var start_pos = _get_attachment_point_position(instigator, instigator_attachment_point)
		var end_pos = _get_attachment_point_position(target, target_attachment_point)
		
		# 如果特效节点实现了 update_positions 方法，调用它
		if beam.has_method("update_positions"):
			beam.update_positions(start_pos, end_pos)
		elif beam.has_method("set_start_and_end"):
			beam.set_start_and_end(start_pos, end_pos)
		else:
			# 否则，更新位置属性
			if beam.has("start_point"):
				beam.start_point = start_pos
			if beam.has("end_point"):
				beam.end_point = end_pos
			# 更新节点位置为起点和终点的中点
			beam.global_position = (start_pos + end_pos) / 2.0
	
	# 清理无效的特效
	for target in to_remove:
		_cleanup_beam(target)

## 停止 Cue（从目标身上移除特效）
## [param] target: Node 目标节点
func _stop(target: Node = null) -> void:
	if not is_instance_valid(target):
		# 如果没有指定目标，清理所有特效
		for t in _active_beams.keys():
			_cleanup_beam(t)
		_active_beams.clear()
		return
	
	# 清理指定目标的特效
	_cleanup_beam(target)

## 清理特效
## [param] target: Node 目标节点
func _cleanup_beam(target: Node) -> void:
	if not _active_beams.has(target):
		return
	
	var beam = _active_beams[target]
	if is_instance_valid(beam):
		# 如果特效节点实现了 cleanup 方法，调用它（用于播放消失动画）
		if beam.has_method("cleanup"):
			beam.cleanup()
		else:
			# 否则直接销毁
			beam.queue_free()
	
	_active_beams.erase(target)

