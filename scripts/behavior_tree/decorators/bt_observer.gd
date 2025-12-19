extends BTDecorator
class_name BTObserver

## 中断类型
enum AbortType {
	NONE,           # 不中断，仅作为普通条件使用
	SELF,           # 如果自身正在运行且条件不再满足，中断自己
	LOWER_PRIORITY, # 如果优先级较低的节点正在运行且条件变得满足，中断它们
	BOTH            # 两者兼有
}

@export var abort_type: AbortType = AbortType.NONE

## [核心] 节点激活时（Enter），注册监听
func _enter(instance: BTInstance):
	if abort_type != AbortType.NONE:
		# 告诉 Instance：我要监听黑板变化
		instance.register_observer(self)

## [核心] 节点结束时（Exit），注销监听
func _exit(instance: BTInstance):
	if abort_type != AbortType.NONE:
		instance.unregister_observer(self)

## [虚函数] 检查条件是否满足
func check_condition(instance: BTInstance) -> bool:
	return true

## [虚函数] 检查变更的 Key 是否与我有关
func is_relevant(key: String) -> bool:
	return false

## [回调] 当黑板数据改变时，由 Instance 调用此函数
func on_blackboard_change(instance: BTInstance, key: String):
	# 子类判断 key 是否是自己关心的变量
	if not is_relevant(key): return 
	
	var is_success = check_condition(instance)
	var status = BTNode.Status.SUCCESS if is_success else BTNode.Status.FAILURE
	
	# 调用 Instance 的中断逻辑
	instance.evaluate_interruption(self, status)
