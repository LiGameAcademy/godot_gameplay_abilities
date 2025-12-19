extends Resource
class_name BTNode

enum Status { SUCCESS, FAILURE, RUNNING }

## 增加 delta 参数，这对计时类节点至关重要
func tick(instance: BTInstance, delta: float) -> int:
	# 1. 检查是否是“首次进入”
	# 我们利用黑板来判断这个节点上一帧是否在运行
	# 如果黑板里没有关于自己的状态记录，说明是刚刚被父节点调度到
	if not instance.blackboard.has_node_data(self):
		_enter(instance)
	
	# 2. 执行具体的业务逻辑 (由子类实现)
	var result = _tick(instance, delta)
	
	# 3. 处理生命周期结束
	if result != Status.RUNNING:
		# 如果结果是 成功 或 失败，说明节点运行结束
		_exit(instance)
		# 清理运行状态
		instance.blackboard.erase_node_data(self)
	else:
		# 如果是 RUNNING，标记自己正在运行 (存个占位符即可，或者存具体状态)
		if not instance.blackboard.has_node_data(self):
			instance.blackboard.set_node_data(self, true)
			
	return result

## 强制清理状态 (用于中断)
func reset(instance: BTInstance) -> void:
	# 如果当前被标记为正在运行，则触发退出逻辑
	if instance.blackboard.has_node_data(self):
		_exit(instance)
		instance.blackboard.erase_node_data(self)

## 快速获取 Agent
func _get_agent(instance: BTInstance) -> Node:
	return instance.agent

## 快速获取/设置属于该节点的私有数据 (使用 self 为 key)
func _get_var(instance: BTInstance, key: String, default: Variant = null) -> Variant:
	return instance.blackboard.get_var(key, default)

func _set_var(instance: BTInstance, key: String, value: Variant) -> void:
	instance.blackboard.set_var(key, value)

func _has_var(instance: BTInstance, key: String) -> bool:
	return instance.blackboard.has_var(key)

func _clear_var(instance: BTInstance, key: String) -> void:
	instance.blackboard.erase_var(key)

## [语法糖] 获取我的私有变量
func _get_storage(instance: BTInstance, default: Variant = null) -> Variant:
	return instance.blackboard.get_node_data(self, default)

## [语法糖] 设置我的私有变量
func _set_storage(instance: BTInstance, value: Variant) -> void:
	instance.blackboard.set_node_data(self, value)

## [语法糖] 清理
func _clear_storage(instance: BTInstance) -> void:
	instance.blackboard.erase_node_data(self)

## [虚函数] 业务逻辑入口
## 子类不要重写 tick()，而是重写 _tick()
func _tick(instance: BTInstance, delta: float) -> int:
	return Status.SUCCESS

## [虚函数] 节点激活时调用 (只调用一次)
## 用于：注册观察者、初始化临时变量、播放开始动画
func _enter(instance: BTInstance) -> void:
	pass

## [虚函数] 节点结束时调用 (成功或失败都会调用)
## 用于：注销观察者、清理临时变量、停止动画
func _exit(instance: BTInstance) -> void:
	pass
