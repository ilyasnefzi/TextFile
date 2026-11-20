# Milestone 9 - Proposed Runtime Architecture

**Project:** MotionMatchingLab  
**Engine:** Godot 4.7.2  
**Status:** PROPOSAL ONLY - NOT APPROVED, NOT IMPLEMENTED  
**Date:** 2026-11-20

---

## 1. Scope and constraints

This document proposes how to integrate the already validated Motion Matching components into a real playable third-person character.

### Hard constraints honored by this proposal

1. Do not modify any production file.
2. Do not modify C++ source or rebuild the extension.
3. Do not modify the animation database or its eligibility rules.
4. Do not change any existing validated controller.
5. Do not start implementation yet.
6. Inspect the existing project and identify reusable components.
7. Do not assume diagnostic code is production-ready.

### What this document changes

- It creates **one new document**: this file.
- It does **not** change any existing script, scene, resource, `.gdextension`, native source, binary, database, catalog, report, manifest, or validation log.
- It does **not** change `project.godot`, the main scene, input actions, physics settings, or rendering settings.
- It does **not** start Milestone 9 implementation.

---

## 2. Investigation summary

### 2.1 Current project state

The project is a research and diagnostic lab, not yet a playable game.

Verified facts:

- The configured main scene is `res://test_node.tscn`, which only runs `res://test_motion_matching.gd` to write `user://animation_inventory.txt`.
- There is no production `CharacterBody3D` player controller.
- There is no production third-person camera rig.
- There is no `SpringArm3D` in first-party scenes.
- There is no target-lock, target-cycle, or combat-facing system.
- There are no autoloads.
- There is no project-level `physics_ticks_per_second` override.
- `project.godot` already defines `move_forward`, `move_backward`, `move_left`, `move_right`, `sprint`, and `combat_mode`.
- `combat_mode` is a held input boolean only; it does not acquire a target or rotate the character.
- The closest playable scene is `res://root_motion_test.tscn`, which is explicitly a diagnostic.
- The closest visual preview is `res://MotionMatching/animation_visual_review.tscn`, which is explicitly diagnostic-only.

### 2.2 Existing validation evidence

All existing suites are passing and must remain unchanged by M9:

| Suite | Result |
| --- | ---: |
| Coordinate-space validation | 42 passed, 0 failed |
| Movement intent validation | 307 passed, 0 failed |
| Movement prediction validation | 102 passed, 0 failed |
| Trajectory prediction validation | 270 passed, 0 failed |
| Query validation | 256 passed, 0 failed |
| Search validation | 132 passed, 0 failed |
| Movement phase validation | 181 passed, 0 failed |
| Animation selection validation (M8) | 264 passed, 0 failed |
| Compatibility validation (M8.1) | 313 passed, 0 failed |
| Visual review validation (M8.2) | 143 passed, 0 failed |

Total: **2010 passed, 0 failed** across these ten suites.

Baseline integrity also passes:

- M8.1: 3478 files checked, 0 missing, 0 changed.
- M8.2: 3753 files checked, 140 generated entries skipped, 0 missing, 0 changed.

### 2.3 Core architectural finding

The validated components are deliberately passive:

- `MovementIntentController` computes intent.
- `MovementPredictionController` computes velocity and future displacement.
- `TrajectoryPredictionController` computes straight/orbit/blended trajectories.
- `MovementPhaseController` classifies `IDLE`, `START`, `SUSTAINED`, `STOP`, and `TURN`.
- `MotionMatchingQueryBuilder` builds the native query shape.
- `MotionMatchingSearchController` loads the database and calls native search.
- Native `MotionMatchingSearch` returns candidate sample data.

None of them:

- move a `CharacterBody3D`;
- play an animation;
- own an `AnimationTree`;
- apply root motion;
- enforce M8.1 posture compatibility;
- select explicit start/stop/turn clips;
- acquire a combat target;
- own character yaw.

Therefore M9 is primarily an **orchestration and presentation integration milestone**, not a new search-algorithm milestone.

### 2.4 Diagnostic code is not production-ready

The following are useful as evidence or offline generators but must not be promoted unchanged to runtime:

- `animation_asset_catalog_diagnostic.gd`
- `animation_selection_diagnostic.gd`
- `animation_compatibility_audit.gd`
- `animation_visual_review.gd`
- all `*_test.gd`, `*_validation.gd`, `*_diagnostic.gd`, `inspect_*.gd`, and `scan_*.gd`
- `root_motion_test.gd`
- `test_motion_matching.gd`
- all generated `user://` reports and baseline manifests

`animation_candidate_selector.gd` and `animation_compatibility_classifier.gd` contain valuable deterministic logic, but their headers explicitly mark them `DIAGNOSTIC ONLY`, they read generated `user://` reports, and they have no production call sites. They should feed an offline-curated runtime data resource, not become runtime singletons.

---

## 3. Recommended runtime architecture

### 3.1 Architectural principles

1. **Add, do not edit.** New M9 code lives in new files and new scenes. Existing validated controllers are reused unchanged.
2. **One owner per frame.** A new `MotionRuntimeDirector` owns the deterministic update order. No controller self-processes in production.
3. **Phases classify; policies decide.** `MovementPhaseController` remains a pure classifier. A new policy layer turns phase + gameplay state into clip requests.
4. **AnimationTree owns playback.** Runtime code must not call `AnimationPlayer.play()` directly once an `AnimationTree` is active.
5. **Native search stays inside its validated contract.** No new C++ cost terms, no eligibility changes, no database rebuild.
6. **Target-facing is a local-frame problem.** Because native query yaw and future yaw deltas are fixed at zero, combat facing must be represented by the facing reference frame rather than by changing C++.
7. **Unsupported means unsupported.** No silent substitution with unrelated, crouch-family, or visually unreviewed clips.
8. **Golden diagnostics stay golden.** Existing validations and baseline manifests are regression oracles, not runtime dependencies.

### 3.2 Layer cake

```text
PRESENTATION
  ThirdPersonCameraRig
  Debug telemetry overlay
        |
        | reads state / listens to signals
        v
LOGIC
  MotionRuntimeDirector
  CombatTargetComponent
  CharacterFacingController
  MotionSelectionPolicy
  AnimationTreeController
  RootMotionIntegrator
        |
        | calls unchanged controllers
        v
DATA
  RuntimeAnimationPolicyData (new Resource)
  Existing motion_database.json (read-only input)
  Existing catalog/selection/compatibility reports (offline evidence only)
        |
        v
INFRASTRUCTURE
  Native MotionMatchingSearch via existing search controller / new session adapter
  Existing InputMap actions
```

Signals flow upward. Calls flow downward. No global signal bus is needed for M9; keep communication inside the player scene and use direct signals where needed.

### 3.3 Proposed scene topology

```text
PlayerCharacter (CharacterBody3D)                  [NEW: PlayerMotionBody.gd]
├── CollisionShape3D                               [NEW: CapsuleShape3D]
├── Visual/
│   ├── Character_01                               [EXISTING GLB instance]
│   │   └── AnimationPlayer                        [EXISTING generated player]
│   └── AnimationTree                              [NEW configuration]
├── AimFacingPivot (Node3D)                        [NEW]
└── MotionRuntimeDirector (Node)                   [NEW]
    ├── MovementIntentController                   [EXISTING, unchanged]
    ├── MovementPredictionController               [EXISTING, unchanged]
    ├── TrajectoryPredictionController             [EXISTING, unchanged]
    ├── MovementPhaseController                    [EXISTING, unchanged]
    ├── MotionMatchingQueryBuilder                 [EXISTING, unchanged]
    ├── MotionMatchingSearchController             [EXISTING, unchanged]
    ├── MotionSearchSession                        [NEW]
    ├── CombatTargetComponent                      [NEW]
    ├── CharacterFacingController                  [NEW]
    ├── MotionSelectionPolicy                      [NEW, RefCounted/Resource-backed]
    ├── AnimationTreeController                    [NEW]
    ├── RootMotionIntegrator                       [NEW]
    └── MotionTelemetry                            [NEW]

ThirdPersonCameraRig (Node3D)                      [NEW scene]
├── SpringArm3D                                    [NEW, world collision mask]
│   └── Camera3D                                   [NEW]
└── CameraOrientation logic                        [NEW script on rig root]
```

The camera rig is a sibling of the player, not a child of the physics body. This avoids inheriting physics jitter and body roll.

---

## 4. Required new scripts and responsibilities

All proposed paths are additive under `res://Runtime/MotionMatching/`.

| New script | Base | Responsibility |
| --- | --- | --- |
| `PlayerMotionBody.gd` | `CharacterBody3D` | Owns collision, floor state, gravity if needed, final velocity, and `move_and_slide()`. Owns the authoritative transform. Does not choose animations. |
| `ThirdPersonCameraRig.gd` | `Node3D` | Owns yaw/pitch state, SpringArm3D occlusion, smooth follow, and exposes the camera basis as the movement-intent reference. |
| `CombatTargetComponent.gd` | `Node` | Acquires, validates, clears, and exposes the current combat target. Uses existing `combat_mode`; no InputMap change in the first stage. |
| `CharacterFacingController.gd` | `Node` | Owns character yaw as a scalar. Smoothly faces the target in combat mode or movement heading otherwise. Owns `AimFacingPivot`. Prevents root rotation and facing logic from fighting. |
| `MotionRuntimeDirector.gd` | `Node` | Owns explicit update order. Disables `update_in_process` on all self-processing controllers. Wires references. Emits high-level runtime state. |
| `MotionSearchSession.gd` | `Node` | Owns exactly one native `MotionMatchingSearch` instance, loads the database once, exposes continuous search, and injects the same instance into the existing `MotionMatchingSearchController`. |
| `RuntimeAnimationPolicyData.gd` | `Resource` | Curated offline data: reviewed clip names, library/path, phase, posture, gait, direction, speed range, turn style, support flag, and fallback reason. No database rules. |
| `MotionSelectionPolicy.gd` | `RefCounted` | Pure policy: converts phase + prediction + trajectory + search result + policy data into a `ClipRequest` and fallback reason. Does not touch nodes. |
| `AnimationLibraryResolver.gd` | `RefCounted` | Builds and owns the immutable `animation_index -> library/clip path` lookup from the read-only database array and `AnimationPlayer.has_animation()`. |
| `AnimationTreeController.gd` | `Node` | Owns AnimationTree parameter writes and state-machine `travel()` requests. Sets dynamic `AnimationNodeAnimation` clip, duration, loop mode, and start offset. Never calls `AnimationPlayer.play()`. |
| `RootMotionIntegrator.gd` | `Node` | Reads root-motion translation/rotation once per physics tick, discards seek/switch deltas, clamps invalid spikes, and supplies velocity/rotation to `PlayerMotionBody`. |
| `MotionTelemetry.gd` | `Node` | Rate-limited, debug-only state: phase, query validity, search result, selected clip, fallback reason, timings, root-motion delta, and frame budget counters. |
| `M9ValidationHarness.gd` and stage-specific validators | `Node` | New headless validation scenes for each stage. Do not modify existing validation scenes. |

### 4.1 New data resource schema

`RuntimeAnimationPolicyData` should be small and hand-curated from existing evidence. Suggested fields per entry:

- `clip_name: String`
- `source_library: String`
- `runtime_path: String` derived as `<library>/<clip_name>`
- `phase: int` using `MovementPhaseController.Phase`
- `posture: String` (`STANDING`, `CROUCHING`, `UNKNOWN`)
- `gait: String` (`IDLE`, `WALK`, `RUN`, `SPRINT`, `CROUCH_LOCOMOTION`, `UNKNOWN`)
- `direction: String` using measured direction, not name-derived direction
- `turn_style: String` (`PIVOT`, `TRANSLATING`, `N/A`)
- `min_speed`, `max_speed`
- `min_angle_deg`, `max_angle_deg` for turns
- `supported: bool`
- `review_status: String` from M8.2
- `fallback_reason: String`
- `notes: String`

Important: measured direction labels must come from M7/M8 analysis. Several asset names are inverted relative to measured motion, for example `RR` measuring left and `LL` measuring right.

---

## 5. Existing scripts that can be reused unchanged

### 5.1 Reuse directly in the runtime scene

| Existing file | Reuse role |
| --- | --- |
| `res://MotionMatching/movement_intent_controller.gd` | Camera-relative input to local/world intent. Set `reference_node` to the camera and `reference_forward_axis = NEGATIVE_Z`. |
| `res://MotionMatching/movement_prediction_controller.gd` | Velocity prediction and 0.2/0.4/0.6 s displacement. Set `facing_reference` to `AimFacingPivot` and `facing_forward_axis = POSITIVE_Z`. |
| `res://MotionMatching/trajectory_prediction_controller.gd` | Straight/orbit/blended trajectory and curvature diagnostics. Feed real actor position and target node. |
| `res://MotionMatching/movement_phase_controller.gd` | Sole phase classifier. Subscribe to `phase_changed`. Keep its passive contract. |
| `res://MotionMatching/motion_matching_query_builder.gd` | Builds the exact native query shape. Keep `allow_identity_fallback = false`. |
| `res://MotionMatching/motion_matching_search_controller.gd` | Database load, query validation, throttling, signals, and basic search boundary. |
| `res://Native/motion_matching.gdextension` | Loads the existing native class. Do not modify or rebuild. |
| Native `MotionMatchingSearch` class | Use `load_database()`, `search_best_match()`, `search_best_match_continuous()`, counts, and `get_last_error()`. No source changes. |
| `res://Assets/Characters/Character_01.glb` | Character mesh and skeleton. Do not modify. |
| `res://Assets/Animations/{Idle,Walk,Run,Sprint,Crouch}.glb` | Animation libraries. Do not modify. |
| Existing `project.godot` input actions | Reuse `move_*`, `sprint`, and `combat_mode`. No InputMap change in the first M9 stage. |

### 5.2 Reuse as offline evidence, not runtime code

| Existing asset | Use |
| --- | --- |
| `user://motion_database.json` | Read-only native database. Hash-pinned. Never regenerate during M9. |
| `user://animation_asset_catalog.json` | Offline source for measured metadata and curated runtime policy data. |
| `user://animation_selection_report.json` | Offline source for reviewed phase winners and documented gaps. |
| `user://animation_compatibility_report.json` | Offline source for substitutions, rejections, and posture/gait decisions. |
| `user://animation_visual_review_report.json` | Manual QA evidence. Not runtime logic. |
| `animation_candidate_selector.gd` | Offline generator input for curated policy data. Not a runtime singleton. |
| `animation_compatibility_classifier.gd` | Offline generator input for curated policy data. Not a runtime singleton. |
| `root_motion_test.gd` | Reference pattern only for AnimationTree dynamic clip switching and root motion. Do not copy verbatim as production code. |

---

## 6. Required integration points

| From | To | Purpose |
| --- | --- | --- |
| `ThirdPersonCameraRig` camera | `MovementIntentController.reference_node` | Camera-relative WASD intent. Axis `NEGATIVE_Z`. |
| `CharacterFacingController` pivot | `MovementPredictionController.facing_reference` | Local-facing conversion frame. Axis `POSITIVE_Z`. |
| `PlayerMotionBody.global_position` | `TrajectoryPredictionController.set_actor_position()` | Real actor origin each physics tick. |
| `CombatTargetComponent` | `TrajectoryPredictionController.set_target_node()` / `clear_target()` | Real target for orbit prediction. |
| `MovementIntentController` | `MovementPredictionController` | Intent to desired velocity. |
| `MovementPredictionController` | `TrajectoryPredictionController`, `MovementPhaseController`, `MotionMatchingQueryBuilder` | Shared velocity prediction. |
| `TrajectoryPredictionController` | `MovementPhaseController`, `MotionMatchingQueryBuilder`, `MotionSelectionPolicy` | Curvature/orbit diagnostics and future positions. |
| `MovementPhaseController.phase_changed` | `MotionSelectionPolicy`, `MotionTelemetry` | Invalidate/re-evaluate clip family on phase change. |
| `MotionMatchingQueryBuilder.get_query_report()` | Search boundary | Reject invalid queries before native calls. |
| `MotionMatchingSearchController` signals | `MotionSelectionPolicy`, `MotionTelemetry` | `database_load_completed`, `search_completed`, `search_rejected`. |
| `MotionSearchSession` | Native `MotionMatchingSearch` | Continuous search with current animation index/time. |
| `MotionSelectionPolicy` | `AnimationTreeController` | Emits reviewed `ClipRequest` with clip path, phase state, blend policy, and start time. |
| `AnimationTreeController` | `RootMotionIntegrator` | Notifies on clip switch/seek so root delta can be discarded once. |
| `RootMotionIntegrator` | `PlayerMotionBody` | Supplies root-motion-derived velocity and optional yaw delta. |
| All new state | `MotionTelemetry` | Rate-limited runtime diagnostics, not a runtime dependency. |

### 6.1 Controller processing ownership

The existing controllers have inconsistent defaults:

- `MovementIntentController.update_in_process = true`
- `MovementPhaseController.update_in_process = true`
- `MovementPredictionController.update_in_process = false`
- `TrajectoryPredictionController.update_in_process = false`
- Query builder and search controller have no frame processing

`MotionRuntimeDirector` must set all self-processing flags to `false` and call update methods explicitly in one deterministic order. This does not modify the controller scripts.

---

## 7. Runtime update sequence

### 7.1 Input events

1. Mouse/keyboard events update camera yaw and pitch **variables** in `ThirdPersonCameraRig`.
2. Existing InputMap actions continue to supply movement, sprint, and combat mode.
3. No gameplay state is mutated directly from `_input()` beyond storing look deltas.

### 7.2 Physics frame

```text
1. Apply camera yaw/pitch to the camera rig transform.
2. Update CombatTargetComponent validity.
3. Update CharacterFacingController yaw:
   - target direction when combat target is valid;
   - movement/camera heading otherwise.
4. MovementIntentController.update_movement_intent()
5. MovementPredictionController.update_prediction(delta)
6. TrajectoryPredictionController.set_actor_position(body.global_position)
7. TrajectoryPredictionController.update_trajectory(delta)
8. MovementPhaseController.update_phase(delta)
9. MotionSelectionPolicy.evaluate(phase, prediction, trajectory)
10. If query is needed:
    a. MotionMatchingQueryBuilder.update_query()
    b. Validate get_query_report()
    c. Search at throttled interval using the validated arguments
11. MotionSelectionPolicy.resolve_clip_request(search_result)
12. AnimationTreeController.apply_clip_request_if_changed()
13. RootMotionIntegrator.read_root_motion(delta)
14. PlayerMotionBody.velocity = integrated_world_motion / delta
15. PlayerMotionBody.move_and_slide()
16. MotionTelemetry.publish_rate_limited_state()
```

Rules:

- Movement and root motion happen only in `_physics_process()`.
- No `await` in `_physics_process()`.
- Native search is not called every physics frame.
- Root motion is read exactly once per physics frame.
- Clip switch/seek delta is discarded once, following the proven `root_motion_test.gd` pattern.

### 7.3 Render frame

1. Smooth camera follow using `SpringArm3D` and guarded position smoothing.
2. Update debug telemetry overlay if enabled.
3. Do not mutate gameplay state in `_process()`.

---

## 8. Animation playback and root-motion strategy

### 8.1 AnimationTree ownership

Use an `AnimationTree` as the only playback owner.

Rules:

- Set `animation_tree.active = true` once during setup.
- Set `anim_player` to the character's existing `AnimationPlayer`.
- Set `root_motion_track` to `NodePath("Armature/Skeleton3D:root")`, matching the database builder and `root_motion_test.gd`.
- Do not call `AnimationPlayer.play()` from production M9 code.
- Use state-machine `travel()` or explicit state start through `AnimationNodeStateMachinePlayback`.
- Use relative parameter paths such as `parameters/StateMachine/...`.
- Guard parameter writes; only write when the value changes.
- Do not enable `auto_advance` for interactive gameplay states.

### 8.2 Dynamic clip switching

The existing `root_motion_test.gd` proves a viable pattern:

1. Cast the tree root to `AnimationNodeStateMachine`.
2. Get the dynamic `AnimationNodeAnimation` state, such as `Run`.
3. Set `animation` to the mapped runtime path.
4. Set `use_custom_timeline = true`.
5. Set `timeline_length` to database duration.
6. Set `stretch_time_scale = false`.
7. Set `loop_mode = Animation.LOOP_LINEAR` for loops.
8. Set `start_offset` from the selected sample time.
9. Start/travel to the state.
10. Call `animation_tree.advance(0.0)`.
11. Call `get_root_motion_position()` once to discard the seek delta.

M9 should productionize this pattern, not copy its hard-coded velocities, one-state graph, or diagnostic logging.

### 8.3 State machine states

Minimum states:

- `Idle`
- `Start`
- `Locomotion`
- `Stop`
- `Turn`

Each state uses a dynamic `AnimationNodeAnimation` node whose clip can be swapped from `RuntimeAnimationPolicyData` or a validated native result.

For later combat layering, a nested upper-body state machine or `BlendTree` overlay can be added, but M9 should first prove the base locomotion loop.

### 8.4 Native result mapping

1. Use the read-only database array order to build `animation_index -> clip_name`.
2. Use `source_file.get_file().get_basename()` to build the library name.
3. Resolve `library/clip_name` with `AnimationPlayer.has_animation()`.
4. Reject missing mappings; never guess a path.
5. Validate `time` against `duration`.
6. Cache the lookup once at startup.

### 8.5 Root motion application

- Translate: `world_motion = body.global_transform.basis * root_motion_position`; `velocity = world_motion / delta`.
- Rotate: read root-motion rotation as telemetry. Apply to body yaw only when no combat target owns facing.
- Target lock: `CharacterFacingController` owns yaw; root rotation is suppressed for visual/facing stability.
- Free locomotion: root rotation may be blended in only after runtime visual validation.
- Clamp non-finite or implausible deltas and discard them.
- If a clip is switched or seeked, discard exactly one root-motion read.

### 8.6 Why query yaw remains zero

The native API accepts `desired_facing_yaw`, but the query builder hard-codes it to `0.0`, and the native search hard-codes desired future yaw deltas to zero. Changing either is out of scope.

M9 handles this without C++ changes by making `AimFacingPivot` the local reference frame:

- forward motion is `+Z` in that frame;
- strafe right/left is `+X` / `-X`;
- backward is `-Z`;
- target-facing is achieved by rotating the pivot, not by requesting nonzero yaw from the search.

This preserves the validated 3-argument native contract while supporting 360-degree movement directions.

---

## 9. Transition handling

### 9.1 Phase-to-clip policy

| Transition | Clip source | Rule |
| --- | --- | --- |
| `IDLE -> START` | `RuntimeAnimationPolicyData`, M8.1 standing substitutions | Use reviewed direction-specific start clip. Unsupported left/right/back-diagonal starts report `UNSUPPORTED`; do not substitute unrelated motion. |
| `START -> SUSTAINED` | Native search result | Begin sustained search once phase is `SUSTAINED`. Use continuous search when available. |
| `SUSTAINED -> STOP` | `RuntimeAnimationPolicyData`, reviewed stop clips | Use direction-specific reviewed stop clip. Full deceleration is expected, not a defect. |
| `STOP -> IDLE` | `RuntimeAnimationPolicyData`, reviewed idle clip | Enter idle only after stop completion or phase classification. |
| `SUSTAINED -> TURN` | `RuntimeAnimationPolicyData`, reviewed turn clips | Use explicit standing pivot or translating reface clip. Native search does not provide turn clips. |
| `TURN -> SUSTAINED` | Reviewed reface/sustained combination | Prefer translating-turn-to-sustained evidence. Do not force pivot-to-sustained without new visual validation. |
| Combat strafe direction change | Native sustained search | Keep facing target; change local velocity direction. Do not classify as `TURN` if facing is stable. |
| Unsupported orbit/curve | Safe fallback | Report unsupported; use ordinary locomotion plus facing rotation. Do not force circle-strafe clips outside their measured band. |

### 9.2 Blend policy

- Use AnimationTree state-machine crossfade times as exported configuration.
- Use `travel()` rather than advance conditions for locomotion intent.
- Avoid `auto_advance`.
- Guard state changes during `START`, `STOP`, and `TURN` so they are not interrupted every frame by search chatter.
- Use a minimum phase duration from `MovementPhaseController` plus policy-level minimum clip hold time.
- On same-clip continuous-search decisions, do not restart the clip; update telemetry only.

### 9.3 Compatibility enforcement

`MotionSelectionPolicy` must reject:

- crouch-family clips for standing requests;
- clips with posture or gait `UNKNOWN` when a known compatible alternative exists;
- unsupported start directions from the M8.1 gap list;
- clips whose measured direction/speed does not match the request;
- any clip not present in `RuntimeAnimationPolicyData` for explicit phase transitions.

Armed state remains `UNKNOWN` for all 718 clips, so combat-armed animation matching is not claimable in M9.

---

## 10. Error handling and fallback behavior

| Condition | Detection | Response |
| --- | --- | --- |
| Native extension fails to load | Class unavailable or instance creation fails | Enter safe camera/idle mode; log clear error; no crash. |
| Database missing | `FileAccess.file_exists()` / controller load signal | Do not start search; use reviewed idle only; report path. |
| Database hash mismatch | New read-only startup validator | Refuse search; enter safe mode; report expected/actual hash. |
| Database parse/load failure | `load_database()` false / `get_last_error()` | Safe mode; no partial database use. |
| Invalid query | `MotionMatchingQueryBuilder.get_query_report()` | Skip native call; emit reason; hold last safe clip briefly, then idle. |
| Native search failure | `search_completed(false, ...)` or result `success == false` | Hold last safe clip for bounded time; then decelerate to idle. |
| No eligible samples | Native error string | Same as search failure; record `NO_ELIGIBLE_SAMPLES`. |
| Missing runtime animation path | `AnimationPlayer.has_animation()` false | Reject clip; use next reviewed compatible clip; if none, idle with `MISSING_CLIP`. |
| Invalid sample time/duration | Range check | Reject result; never seek outside duration. |
| Unsupported transition/request | Policy data `supported == false` | Emit explicit `UNSUPPORTED`; do not silently substitute. |
| Target lost | `CombatTargetComponent` validity check | Clear lock; trajectory target cleared; facing returns to movement/camera heading. |
| Root-motion NaN/Inf | Finite checks | Discard delta for that frame; increment telemetry counter. |
| Root-motion spike | Configurable max m/s threshold | Clamp or discard; log; if repeated, fall back to velocity-driven movement. |
| Clip switch/seek | `AnimationTreeController` notification | Discard exactly one root-motion read. |
| Release build attempted | Missing release DLL | Report platform/packaging blocker; do not rebuild under M9 constraints. |

### 10.1 Fallback priority

1. Last known good compatible clip, bounded by a short hold time.
2. Reviewed idle clip.
3. Safe stationary body with telemetry error.

Never fall back to:

- crouch-family clips for standing requests;
- unreviewed clips;
- clips identified as unsupported;
- unrelated animations chosen only because they are available.

---

## 11. Performance considerations

### 11.1 Database and native search

- Load the database once. One native instance only.
- Inject the same native instance into the existing search controller; do not let two systems each load 62 MB.
- Keep search at the validated default interval of `0.2 s` (~5 Hz) until profiling proves a different rate is safe.
- Do not call native search from `_process()`.
- Cache search results; avoid calling `get_result()` and `get_top_matches()` repeatedly per frame because they deep-copy dictionaries.
- Treat the full scan of 3191 eligible samples as a known cost. The per-query path allocates and sorts all eligible candidates.

### 11.2 Animation and scene

- Guard every AnimationTree parameter write.
- Avoid deep BlendTrees in the first runtime stage.
- Use `BlendSpace1D` only if speed-only blending is added later; use `BlendSpace2D` only for true two-axis strafe blending.
- Preload or resolve clip paths once; never `load()` in a hot path.
- Use `StringName` keys for hot state dictionaries.
- Avoid absolute node paths in new scripts. Use exported `NodePath`s or unique names.
- Keep camera follow in `_process()` with smoothing; keep body movement in `_physics_process()`.
- Consider explicitly setting 60 Hz physics in the new runtime director only if approved; do not modify `project.godot` in this proposal.

### 11.3 Budgets

Initial desktop targets:

- Script time below 8 ms per frame.
- No native search main-thread spike above the agreed profiling threshold before stage acceptance.
- Zero per-frame disk I/O.
- Zero per-frame JSON parsing.
- Zero per-frame `get_nodes_in_group()` or scene-tree searches.
- Telemetry logging rate-limited and disabled by default in normal play.

---

## 12. Risks and dependencies

| Risk / dependency | Impact | Mitigation |
| --- | --- | --- |
| Release DLL is missing; only Windows debug binary exists | Release/export builds cannot load the extension | Stay on Windows debug validation; obtain a release binary externally. Do not rebuild in M9. |
| Database is 62 MB in `user://`, not packaged | Fresh installs have no database | Treat provisioning as a separate packaging decision; do not regenerate database. |
| Database hash and counts are pinned in validations | Regeneration breaks baselines | Read-only use; startup hash check; no builder nodes in M9 scene. |
| Native eligibility excludes start, stop, turn, crouch, idle, reface, transition, arc | Native search cannot supply phase transitions | Explicit reviewed clip policy for non-sustained phases. |
| Query yaw and future yaw deltas are effectively zero | Turning-aware native queries unavailable | Use facing pivot local frame; explicit turn clips. |
| Circle-strafe coverage is narrow (~0.5-1.3 m/s, small radii) | Full-speed 360 strafing may be unsupported | Reject unsupported orbit requests; use normal locomotion plus facing. |
| Asset names can invert measured direction | Wrong clip direction if names are trusted | Use measured metadata in policy data. |
| Four walk-start gaps remain unsupported | Silent fallback would violate review decisions | Explicit `UNSUPPORTED` telemetry and safe idle/hold. |
| Armed state is `UNKNOWN` for all clips | Combat-armed matching cannot be validated | Keep combat scope to facing/strafing; do not claim armed animation quality. |
| M8.2 used simple crossfades | Production transition quality is not proven | Add runtime visual pass with actual AnimationTree transitions. |
| Existing controllers have mixed self-processing defaults | Nondeterministic update order | Director disables self-processing and calls updates explicitly. |
| Duck-typed `Node` references in existing controllers | Refactor fragility | Preserve expected methods/properties exactly; add adapter validation at startup. |
| New AnimationTree graph is required | Runtime authoring effort | Build new scene/resources only; do not modify diagnostic scenes. |

---

## 13. Implementation stages and measurable acceptance criteria

Each stage must be independently testable. No stage should depend on an unproven later stage.

### Stage M9.0 - Frozen baseline and additive harness

**Scope**

- Create new M9 folder/scene skeleton only.
- Confirm no existing file changed.
- Do not implement behavior.

**Acceptance criteria**

- New M9 scene loads headlessly with no script errors.
- All ten existing suites remain exactly passing: 2010 passed, 0 failed total.
- M8.2 remains 143 passed, 0 failed.
- Independent integrity check reports 0 missing and 0 changed production/database/native/baseline files.
- No C++ source changed; no extension rebuild performed.

---

### Stage M9.1 - Playable body and third-person camera

**Scope**

- Add `PlayerMotionBody`, collision, ground, and `ThirdPersonCameraRig`.
- Wire camera as intent reference.
- No search, no animation selection, no root motion yet.

**Acceptance criteria**

- Scene runs standalone with `CharacterBody3D`, capsule collision, character GLB, and camera rig.
- SpringArm3D has a world/environment collision mask.
- WASD produces normalized camera-relative intent for all eight directions.
- Direction error for cardinal/diagonal scripted inputs is at most 5 degrees after deadzone.
- No movement logic runs in `_process()`.
- Camera remains stable under scripted body motion; no hard snap to body transform each frame.
- Existing intent validation remains 307 passed, 0 failed.

---

### Stage M9.2 - Deterministic controller chain

**Scope**

- Wire intent, prediction, trajectory, phase, query builder, and search controller unchanged.
- Director owns explicit update order.
- No playback yet.

**Acceptance criteria**

- All self-processing flags are disabled by the director; asserted in validation.
- Scripted input produces valid query reports for eight directions.
- Every query has exactly 3 future displacements and finite `Vector3` values.
- `allow_identity_fallback` remains false; missing facing reference is rejected, not silently converted.
- Native search succeeds for eligible sustained cases.
- Search call count at 60 Hz input over 1 simulated second is at most 6 at 0.2 s interval.
- Search validation remains 132 passed, 0 failed; query validation remains 256 passed, 0 failed.

---

### Stage M9.3 - Sustained playback and root motion

**Scope**

- Add AnimationTree dynamic state, library resolver, and root-motion integrator.
- Use validated native results for sustained locomotion only.
- No phase transition clips yet.

**Acceptance criteria**

- Runtime code makes zero direct `AnimationPlayer.play()` calls.
- Dynamic clip path, duration, loop mode, and start offset are set from validated result data.
- Every selected clip has a valid runtime mapping; 0 unmapped selections.
- On clip switch, `advance(0.0)` and one discard root-motion read occur exactly once.
- Root motion moves the `CharacterBody3D`; after 5 simulated seconds, integrated displacement error against accumulated root motion is at most 5%.
- No non-finite root-motion delta reaches `velocity`.
- Character remains on the ground plane in scripted tests.
- Existing `root_motion_test.tscn` is unchanged.

---

### Stage M9.4 - Phase-aware transitions

**Scope**

- Add `RuntimeAnimationPolicyData`, `MotionSelectionPolicy`, and Idle/Start/Stop/Turn states.
- Enforce M8.1 compatibility decisions.

**Acceptance criteria**

- Scripted `Idle -> Start -> Sustained -> Stop -> Idle` produces the exact phase sequence.
- Each phase selects a clip from the reviewed policy data, not from native search.
- Standing requests never select crouch-family clips.
- The genuine walk stop plays its full deceleration sequence.
- The four unsupported walk starts emit explicit `UNSUPPORTED` telemetry and do not select unrelated clips.
- Curved/unsupported-speed/turn-angle fallbacks emit explicit reasons.
- AnimationTree `travel()` is used for state changes; no `auto_advance` is enabled.
- M8 selection validation remains 264 passed, 0 failed; M8.1 remains 313 passed, 0 failed.

---

### Stage M9.5 - Combat facing and 360-degree strafing

**Scope**

- Add target component and facing controller.
- Feed real actor and target state to trajectory prediction.
- Validate local-frame query behavior.

**Acceptance criteria**

- With a valid target, character forward reaches within 5 degrees of the target direction after settle.
- Strafing and backpedalling with a stable target do not trigger `TURN`.
- Changing facing toward a new target does trigger `TURN` when thresholds are met.
- All eight local strafe directions produce finite, valid queries.
- Eligible sustained results match measured direction within the existing 25-degree coverage alignment threshold where data exists.
- Unsupported high-speed/small-radius or high-radius orbit requests emit `UNSUPPORTED` and do not force circle-strafe clips.
- Target loss clears trajectory target and returns facing to movement/camera heading.
- Existing phase validation remains 181 passed, 0 failed; trajectory remains 270 passed, 0 failed.

---

### Stage M9.6 - Continuity and fallback hardening

**Scope**

- Add `MotionSearchSession`.
- Use continuous search with one native instance.
- Add all error/fallback paths.

**Acceptance criteria**

- Exactly one `MotionMatchingSearch` instance owns the loaded database.
- Existing search controller receives that same instance via its unchanged API.
- Same-clip continuous-search results do not restart the clip.
- Different-clip results use the returned phase/time correctly.
- Simulated database failure, invalid query, missing clip, search failure, NaN root motion, and root-motion spike each produce a logged fallback and no crash.
- Repeated failure does not create orphan native instances or duplicate search controllers.
- M8.2 remains 143 passed, 0 failed.

---

### Stage M9.7 - Runtime validation, profiling, and manual playtest

**Scope**

- Add a consolidated M9 headless validation scene.
- Profile the playable scene.
- Perform a manual visual pass in the real runtime scene.

**Acceptance criteria**

- New M9 validation reports `RESULT: N passed, 0 failed` and includes every behavioral check from stages M9.0-M9.6.
- All ten existing suites remain unchanged and passing: 2010 passed, 0 failed total.
- Production/database/native/baseline integrity reports 0 changed files.
- Profiling records script time below 8 ms per frame on the target desktop machine.
- Native search frequency is at most 5 Hz during normal play unless explicitly approved.
- Manual runtime review covers idle, start, sustained, stop, turns, all eight strafe directions, target loss, and unsupported fallbacks.
- Manual findings are recorded in a new M9 review artifact; no M8.2 artifact is edited.
- Any new visual issue blocks stage acceptance and is recorded with clip name, phase, and reproduction steps.

---

## 14. Explicit non-goals for M9

To keep the milestone small and testable, the following are explicitly out of scope unless separately approved:

- changing C++ source, weights, horizons, cost terms, or eligibility;
- rebuilding the extension;
- regenerating or editing `motion_database.json`;
- changing M7/M8/M8.1/M8.2 scripts, reports, manifests, or validation results;
- adding new armed/unarmed animation metadata to existing assets;
- proving production-quality transition topology from M8.2 simple crossfades;
- full high-speed circle-strafe combat coverage;
- networked locomotion;
- jump/traversal integration;
- animationmontages, hit reactions, weapon layers, or upper-body combat overlays;
- changing `project.godot` input actions or the project main scene;
- declaring the report status `PASSED` or changing `automatic_visual_passes` in M8.2.

---

## 15. Recommended Milestone 9 breakdown

Recommended order:

1. **M9.0** - Frozen baseline and additive harness.
2. **M9.1** - Playable body and third-person camera.
3. **M9.2** - Deterministic controller chain.
4. **M9.3** - Sustained playback and root motion.
5. **M9.4** - Phase-aware transitions.
6. **M9.5** - Combat facing and 360-degree strafing.
7. **M9.6** - Continuity and fallback hardening.
8. **M9.7** - Runtime validation, profiling, and manual playtest.

This ordering deliberately proves the runtime foundation before adding combat facing, and proves non-native transition policy before claiming 360-degree locomotion quality.

**Awaiting approval before any implementation begins.**
