extends RefCounted
class_name ContextUtils

## 上下文工具类
## 提供 Dictionary 和 AbilityContext 之间的转换，保持向后兼容

## 将 Dictionary 或 AbilityContext 转换为 AbilityContext
## 如果已经是 AbilityContext，直接返回
## 如果是 Dictionary，转换为 AbilityContext
## [param] context: Variant 可以是 Dictionary 或 AbilityContext
## [return] AbilityContext 转换后的上下文
static func to_context(context: Variant) -> AbilityContext:
	if context is AbilityContext:
		return context as AbilityContext
	elif context is Dictionary:
		return AbilityContext.from_dict(context as Dictionary)
	else:
		# 如果为空或无效，创建新的上下文
		return AbilityContext.create()

## 将 AbilityContext 或 Dictionary 转换为 Dictionary
## 如果已经是 Dictionary，直接返回
## 如果是 AbilityContext，转换为 Dictionary
## [param] context: Variant 可以是 Dictionary 或 AbilityContext
## [return] Dictionary 转换后的字典
static func to_dict(context: Variant) -> Dictionary:
	if context is Dictionary:
		return context as Dictionary
	elif context is AbilityContext:
		return (context as AbilityContext).to_dict()
	else:
		# 如果为空或无效，返回空字典
		return {}

## 确保上下文是 AbilityContext 类型
## 如果不是，则转换；如果已经是，则直接返回
## [param] context: Variant 可以是 Dictionary 或 AbilityContext
## [return] AbilityContext 确保是 AbilityContext 类型
static func ensure_context(context: Variant) -> AbilityContext:
	return to_context(context)

