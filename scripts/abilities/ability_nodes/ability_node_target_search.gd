extends BTAction
class_name AbilityNodeTargetSearch

## 目标解析节点
## 使用配置的 TargetingStrategy 查找目标，并将结果写入黑板

#region ========== 配置参数 ==========

## [核心] 目标获取策略资源
@export var strategy: TargetingStrategy

## [输入] 初始目标来源 Key (通常是 context 或 input_target)
## 如果策略依赖"点击的目标"作为中心点（如传染技能），这很重要
@export var input_target_key: String = "target"

## [输出] 结果写入黑板的 Key
@export var write_to_key: String = "targets"

## [逻辑] 如果没找到任何目标，是否视为节点失败？
## True: 返回 FAILURE (中断 Sequence)
## False: 返回 SUCCESS (允许空挥)
@export var fail_if_empty: bool = false

#endregion

func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 安全检查
	if not strategy:
		push_warning("AbilityNodeTargetSearch: Missing strategy.")
		return Status.FAILURE

	var instigator = instance.agent
	var blackboard = instance.blackboard
	
	# 2. 准备输入数据
	# 获取初始输入目标 (可能是玩家点的怪)
	var input_target = blackboard.get_var(input_target_key)
	
	# 获取上下文 (Context)
	# 假设黑板里存的是 AbilityContext 对象，我们需要把它转为 Dictionary 传给策略
	# 或者策略直接接受 AbilityContext (建议统一接口，这里按你的基类要求转字典)
	var context_obj = blackboard.get_var("context")
	var context_dict: Dictionary = {}
	
	if is_instance_valid(context_obj) and context_obj.has_method("to_dict"):
		context_dict = context_obj.to_dict()
	elif context_obj is Dictionary:
		context_dict = context_obj
	
	# 补充必要的上下文信息 (如果 Context 里没有)
	if not context_dict.has("ability_instance"):
		context_dict["ability_instance"] = blackboard.get_var("ability_instance")
	
	# 3. 执行策略 (核心逻辑)
	var found_targets = strategy.resolve_targets(instigator, input_target, context_dict)
	
	# 4. 处理结果
	if found_targets.is_empty():
		if fail_if_empty:
			# 清理黑板，避免残留旧数据
			blackboard.set_var(write_to_key, []) 
			return Status.FAILURE
		else:
			blackboard.set_var(write_to_key, [])
			return Status.SUCCESS
	
	# 5. 写入黑板
	blackboard.set_var(write_to_key, found_targets)
	
	# (可选) 调试绘制
	if OS.is_debug_build():
		_debug_draw_targets(instigator, found_targets)
		
	return Status.SUCCESS

func _debug_draw_targets(origin: Node, targets: Array[Node]) -> void:
	# 简单的调试打印，实际可以用 DebugDraw3D 画线
	print("Strategy [%s] found %d targets" % [strategy.get_description(), targets.size()])
