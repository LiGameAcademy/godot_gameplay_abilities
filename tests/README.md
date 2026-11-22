# Runtime regression checks

Run `python tests/run_runtime.py --godot /absolute/path/to/godot` with Godot 4.5 or 4.7.2 and Python 3.10+.
The runner creates a disposable host with the four GAS autoloads. It checks combo cost/cooldown construction, dictionary contexts, independent game-time waits, reparenting, forgetting and deletion through weak references.

Run `python tests/run_module_profiles.py --godot /absolute/path/to/godot` to validate [partial installs](../MODULES.md). The runner imports seven projects without Autoloads and checks their script boundaries. The Status + Attribute host checks source-specific expiration of a serialized modifier effect. The Status + Vital host checks periodic damage, immunity, expiration, attributed death, and event isolation across two battle scopes. The Ability host runs a custom action without the example templates and checks the activation and cooldown lifecycle for two casters sharing one definition.

`ability_template_compatibility.tscn` checks the full installation. It loads a legacy combo `.tres` with a typed array of active steps, loads a channeling definition embedded in the scene, and builds both generated trees through the original resource scripts.

Vital regressions cover replacing attribute sets, disconnecting old attribute instances, maximum-only and clamped snapshots, atomic payments, shared cost resources, and lethal damage attribution.

Healing regressions exercise the public effect path and Cue context: ordinary and capped recovery, full health, zero capacity, restored capacity, actual death, invalid amounts, and reentrant healing/damage listeners. `HealthVital.heal()` still returns a boolean; `apply_healing()` returns the amount committed by that write before listeners run. `GE_ApplyHealing` publishes `healing_applied` only for positive recovery and writes that same amount to its local `final_healing` context (zero on rejection). This is an intentional correction for consumers that previously treated requested healing as actual recovery; generic effect Cue execution remains unchanged.

Attribute regressions cover independent effect sources, explicit context keys across effect copies, registration snapshots, and rejection of blank or duplicate IDs. An anonymous attribute effect uses the same instance for application and removal. Callers that use separate effect copies should pass the same non-empty context source ID. To change a registered modifier, remove it and register it again with the updated fields.

Dependency regressions check that component subscribers see settled values during initialization and after a change with multiple derived branches. The component publishes one final value per changed attribute in first-change order. A cyclic `set_base_value()` call returns false and logs the dependency path, while other branches continue. Use the component API in dependency hooks to reject a cyclic write before it changes state. A direct instance write has already changed state when the component observes it, so the component stops further propagation and reports the cycle.

Effective attribute changes use exact comparison: tiny writes must still update dependent attributes and Vital maximums. Regressions include 1,000 increments through both component and instance APIs, tiny modifier application/removal, and reinitialization. Subscribers read settled dependency chains from the first notification. Identical effective values, clamped writes, unchanged initialization and cancelling modifier batches stay silent. Consumers that want rounded UI updates can round at the presentation boundary without dropping gameplay updates.

The optional `arpg_attribute_integration.tscn` runs in a separate checkout of Simple ARPG Demo (tested master `11918d4`), with this plugin checked out under `addons/godot_gameplay_abilities`. Run the demo's `python tests/run_checks.py --godot /absolute/path/to/godot`, then `godot --headless --verbose --path /absolute/path/to/demo --fixed-fps 60 res://addons/godot_gameplay_abilities/tests/arpg_attribute_integration.tscn --quit-after 1800`. Require the marker `PASS: ARPG actual healing, potion recovery and precise derived attributes` and no new diagnostics. The fixture exercises the real player, SecondaryAttributeSet, small health potion and life-drain healing resource. It is not run in the standalone plugin host, which has no demo assets.

Lifecycle regressions cover an entire source removal before notifications, a first write that stays below an attribute's minimum, and attributed death after Vital replacement. Consumers that need to observe death across reinitialization can connect to `GameplayVitalAttributeComponent.health_depleted` and filter by Vital ID.

Vital IDs must contain a non-whitespace character. The first valid template for an ID is used. Reinitialization builds replacement attributes and Vitals before publishing changes to existing IDs. Attribute batches refresh all affected Vital maximums and clamp their balances before either component signal is published. Reinitialization and maximum changes do not publish damage or payment events.

For mana assets, use a `GameplayVital` resource with `vital_id = &"mana"` and configure its maximum and regeneration attributes. Existing `ManaVital` resources remain loadable. Skill costs use `can_spend()` and `try_spend()`. Periodic damage can configure `GE_ApplyDamage.fixed_base_damage` and reuse the same damage strategy, immunity checks and death path as direct damage.

The runner fails on script errors, retained resources, ObjectDB leaks and missing pass markers. The composite-effect regression loads nested children saved with the original typed `.tres` format and checks that fresh effect instances own independent arrays. `GameplayEffect.sub_effects` keeps its exported `Array[GameplayEffect]` type. Allocating the empty array at instance creation avoids retaining script resources through Godot's exported defaults.

During attribute_value_changed or vital_value_changed, set_base_value() accepts valid writes and commits them in order after the current notifications finish. Both listeners see the same attribute and derived snapshot. The component also queues individual modifier additions/removals, batch additions and removal by source in the same order. Each batch is one queued operation. The list passed to add_modifiers() is copied when queued, and modifier resources are read when the operation commits. Use component APIs from public notification callbacks.

In a component attribute or Vital value callback, modify_vital() returns true when the request is queued. Eligibility is evaluated against the balance and Vital state at commit. An ineligible request emits no value notification. Outside these callbacks the method returns the synchronous result.

A nonzero try_spend() called during a component snapshot returns false. Use request_spend() to queue a payment in write order and receive its actual success result as a bool in the completion callback.

While the write queue is draining, payment completion callbacks follow the same write rules as snapshot listeners. Their attribute, modifier and Vital requests append to the queue. Nonzero synchronous payments are rejected during those callbacks; request_spend() reports the result after executing.

For a generated ActiveAbilityDefinition tree, ability_activated means the cast was accepted. After windup the tree pays the cost before starting cooldown. The after-commit modifier hook and ability_committed event observe a successful commit; a rejected payment emits ability_commit_failed, followed by the usual ability_completed lifecycle event. Cooldown reduction is prepared before casting so the commit hook can observe the started timer.

CostFeature validates built-in VitalCost groups against a running balance for each Vital, in configuration order. Explicit overdraft still spends the available positive balance, leaving zero for any later cost on that Vital. Failed groups publish no payment notifications. Successful groups update every affected balance before publishing one value notification for each changed Vital. A single custom cost still uses AbilityCostBase; groups containing custom costs are rejected because that interface has no atomic payment contract.

Generated combo trees accept the cast once. Follow-up input advances the running combo without checking costs again. The opening cost node reports success after payment and before the first step, including a free combo, or reports failure without executing a step. Finishing all steps or timing out the follow-up window starts configured cooldown at the end.

For a generated combo, forced cancellation before successful payment has no cost or cooldown. After successful payment, including a free cast, cancellation retains the committed cost and starts configured cooldown before completion observers run. A cancellation requested synchronously during payment is applied once the outcome is known.

After a generated combo commits, a segment body returning FAILURE ends the combo, retains payment and starts the configured cooldown. The ability_combo_step_failed event includes a one-based step_number. The lifecycle still ends with ability_completed. A completed final step or an input-window timeout does not emit the segment failure event.

A generated channel reports acceptance before windup. The first successful payment starts the configured cooldown and reports a commit before the first periodic effect. A rejected first payment emits ability_commit_failed and skips periodic and completion effects. Later payments do not announce another commit or restart cooldown.

Each generated channel tick charges Vital fees atomically to the caster. The target only receives effects. If any fee cannot be paid, the tick leaves the caster's balance untouched and does not apply its periodic effects.
