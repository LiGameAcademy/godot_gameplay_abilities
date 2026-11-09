# Runtime regression checks

Run `python tests/run_runtime.py --godot /absolute/path/to/godot` with Godot 4.7.2 and Python 3.10+.
The runner creates a disposable host with the four GAS autoloads. It checks combo cost/cooldown construction, dictionary contexts, independent game-time waits, reparenting, forgetting and deletion through weak references.

Vital regressions cover replacing attribute sets, disconnecting old attribute instances, maximum-only and clamped snapshots, atomic payments, shared cost resources, and lethal damage attribution.

Attribute regressions cover independent effect sources, explicit context keys across effect copies, registration snapshots, and rejection of blank or duplicate IDs. An anonymous attribute effect uses the same instance for application and removal. Callers that use separate effect copies should pass the same non-empty context source ID. To change a registered modifier, remove it and register it again with the updated fields.

Dependency regressions check that component subscribers see settled values during initialization and after a change with multiple derived branches. The component publishes one final value per changed attribute in first-change order. A cyclic `set_base_value()` call returns false and logs the dependency path, while other branches continue. Use the component API in dependency hooks to reject a cyclic write before it changes state. A direct instance write has already changed state when the component observes it, so the component stops further propagation and reports the cycle.

Lifecycle regressions cover an entire source removal before notifications, a first write that stays below an attribute's minimum, and attributed death after Vital replacement. Consumers that need to observe death across reinitialization can connect to `GameplayVitalAttributeComponent.health_depleted` and filter by Vital ID.

Vital IDs must contain a non-whitespace character. The first valid template for an ID is used. Reinitialization builds replacement attributes and Vitals before publishing changes to existing IDs. Attribute batches refresh all affected Vital maximums and clamp their balances before either component signal is published. Reinitialization and maximum changes do not publish damage or payment events.

For mana assets, use a `GameplayVital` resource with `vital_id = &"mana"` and configure its maximum and regeneration attributes. Existing `ManaVital` resources remain loadable. Skill costs use `can_spend()` and `try_spend()`. Periodic damage can configure `GE_ApplyDamage.fixed_base_damage` and reuse the same damage strategy, immunity checks and death path as direct damage.

Known baseline: Godot 4.7.2 retains the `GameplayEffect` and `GameplayFilterData` scripts at exit (three ObjectDB objects, two script resources). The same diagnostic reproduces with unmodified commit `34bc173` merely preloading `ActiveAbilityDefinition`, without creating any ability instances. The runner prints and allows only that exact resource set and count; other engine errors, script errors, extra retained resources and missing pass markers fail validation. This check does not claim that the baseline script-retention issue is fixed.
