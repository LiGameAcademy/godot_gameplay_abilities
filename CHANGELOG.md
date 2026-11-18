# 更新日志

## v0.0.2

### 属性、Vital 与效果

- 属性和 Vital 的单次及批量修改发布一致的最终快照。回调内的写入按调用顺序处理。派生属性保留微小数值变化，遇到依赖环时停止递归并输出路径。
- 验证属性和 Vital 的 ID 及数值。重新初始化会解绑旧实例，伤害重入时只报告一次死亡并保留击杀归属。
- 组合效果移除会清理嵌套子效果的修饰器。治疗事件只报告实际恢复量，生命上限恢复后可以继续治疗仍存活的目标。
- 默认技能的多项 Vital 费用整组扣除。同一 Vital 的费用按合计余额校验，失败时余额和通知保持不变。

### 技能生命周期

- 默认主动技能区分接受施放与提交结果。扣费成功后才启动冷却。禁用状态在预检和施放入口一致。
- 默认连击支持零费用，整套费用在首段前支付一次。取消和分段失败按提交状态保留已支付费用与冷却，失败事件包含段号。
- 默认引导每跳从施法者原子扣费，首跳成功时提交并启动冷却。结束顺序为强制取消、控制打断、松手、最大时长、周期扣费。已提交后松手或到时才执行完成效果。结束事件报告原因，并支持回调里重施同一技能。

### 升级说明

- 对默认树，`ability_activated` 表示已接受施放。监听 `ability_committed` 或 `ability_commit_failed` 获取实际提交结果。可通过 `ability_combo_step_failed` 和 `ability_channel_ended` 获取失败段号和引导结束原因。
- 平常调用 `try_spend()` 仍同步扣费并返回结果。在属性或 Vital 通知及支付完成回调中，使用 `request_spend()` 按顺序排队并读取实际结果。多项费用使用内置 `VitalCost`，单个自定义费用可继续使用 `AbilityCostBase`。
- 现有 `ManaVital` 资源仍可加载。新法力资源可以使用 `GameplayVital` 并设置 `vital_id` 为 `mana`。重新初始化后要持续监听死亡时，使用组件的 `health_depleted` 信号。
- Godot 4.7.2 的最小预加载在旧版和本版都会报告相同的两个脚本资源保留。回归仅允许该已知基线，新诊断仍会使检查失败。

### English summary

- Attribute and Vital observers read settled snapshots. Effect removal, healing amounts, death attribution and reentrant writes now follow consistent rules.
- Generated active, combo and channeling abilities distinguish acceptance from commitment. Built-in multi-Vital costs are atomic. Channel ticks pay from the caster, and a committed channel applies completion effects on release or timeout.
- Listen for `ability_committed` to act on a successful commit. Use `request_spend()` for payments from notification callbacks. Existing `ManaVital` assets remain loadable.
