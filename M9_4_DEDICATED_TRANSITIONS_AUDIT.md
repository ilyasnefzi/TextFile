# M9.4 Dedicated Locomotion Transition Audit

**Status:** review-only investigation and proposal. No production script, scene, database, manifest, search weight, or shared system was modified. No implementation is authorized by this document.

**Acceptance status:** M9.4 remains **unaccepted** pending the user's manual Test 3 retest of the currently validated `WalkNative -> RunNative` crossfade. Nothing in this document claims visual acceptance of any dedicated transition clip.

**Scope:** replace, where suitable, the current loop-to-loop WALK↔RUN crossfade with authored GASP-derived transition clips that are already imported and database-indexed.

---

## 1. Executive summary

The authored transition clips exist, are loaded at runtime, and are present in the motion database. They are not currently selected by M9.4 policy or native search.

| Transition | Recommended clip | Decision |
|---|---|---|
| WALK → RUN | `Run/M Neutral Transition Walk to Run Lfoot_fit_Armature_001` | **Suitable**. Root speed matches both sustained loops; exit pose is a near-exact match to the RUN loop at `2.000 s`. Use as the primary path, with the existing `0.24 s` native crossfade retained as fallback. |
| RUN → WALK | `Walk/M Neutral Transition Run to Walk Rfoot_fit_Armature_222`, **trimmed to 4.3333 s** | **Suitable with trim**. Entry speed matches RUN; at `4.3333 s` root speed and foot phase match WALK. The untrimmed clip decelerates to `1.2210 m/s` in its last frames and must not be played to full length. |

No directional transition variants exist; only left-foot/right-foot lead variants exist. All relevant candidates are forward-moving in animation-root space (`+Z`, yaw `0 deg`) and rely on the existing authoritative body yaw for world direction.

The dedicated clips are much longer (`3.33–4.50 s`) than the current `0.24 s` crossfade. Their value is authored acceleration/deceleration and footwork, not shorter transitions. They must be one-shot states with short entry/exit blends and explicit interruption rules.

---

## 2. Phase 1 — asset discovery

### 2.1 Complete source animation library

All animation source assets under `Assets/Animations/` are GLB files. No `.gltf`, `.fbx`, `.anim`, `.dae`, `.obj`, or `.blend` animation source files exist in the project.

| Source GLB | Size (bytes) | Embedded clips |
|---|---:|---:|
| `res://Assets/Animations/AimOffset.glb` | 2,202,328 | 42 |
| `res://Assets/Animations/Crouch.glb` | 29,106,200 | 213 |
| `res://Assets/Animations/ExperimentalStateMachineData.glb` | 73,264 | 1 |
| `res://Assets/Animations/Idle.glb` | 3,478,000 | 23 |
| `res://Assets/Animations/Jump.glb` | 7,937,636 | 67 |
| `res://Assets/Animations/Run.glb` | 28,408,608 | 229 |
| `res://Assets/Animations/Sprint.glb` | 4,991,512 | 44 |
| `res://Assets/Animations/Traversal.glb` | 5,848,196 | 44 |
| `res://Assets/Animations/Walk.glb` | 34,709,472 | 224 |

The database builder uses only `Run.glb`, `Walk.glb`, `Sprint.glb`, `Crouch.glb`, and `Idle.glb`. `Jump.glb`, `Traversal.glb`, `AimOffset.glb`, `ExperimentalStateMachineData.glb`, and `Assets/Characters/Character_01.glb` are not database sources.

### 2.2 Dedicated transition clips found by actual content inspection

Clips were enumerated from `AnimationPlayer.get_animation_list()` inside each GLB instance, not from filenames. Each candidate's `Animation` resource was then sampled directly. The GLB JSON names use a dot suffix (`_fit_Armature.001`); Godot and the database expose it as `_fit_Armature_001`.

All 14 transition clips share this measured metadata:

- 69 tracks: 7 position, 62 rotation.
- Root track: `Armature/Skeleton3D:root`.
- `has_root_rotation_motion = false`, one root rotation key, `final_rotation_degrees = 0.0`, `max_rotation_degrees = 0.0`.
- `coordinate_space = "animation_root_parent"`, `pose_coordinate_space = "root_local"`.
- `sample_rate = 30.0 Hz`.
- `pose_feature_bones = ["foot_l", "foot_r"]`.
- Runtime path rule: `<GLB basename>/<database name>`, built by `M94AnimationTreeController._build_animation_lookup()`.

#### WALK→RUN and RUN→WALK candidates

| Role | Runtime path | Source GLB | GLB name | Duration (s) | Tags |
|---|---|---|---|---:|---|
| WALK→RUN L | `Run/M Neutral Transition Walk to Run Lfoot_fit_Armature_001` | `Run.glb` | `M Neutral Transition Walk to Run Lfoot_fit_Armature.001` | 3.833333 | `locomotion_run`, `transition`, `left_foot` |
| WALK→RUN R | `Run/M Neutral Transition Walk to Run Rfoot_fit` | `Run.glb` | `M Neutral Transition Walk to Run Rfoot_fit` | 3.333333 | `locomotion_run`, `transition`, `right_foot` |
| RUN→WALK L | `Walk/M Neutral Transition Run to Walk Lfoot_fit_Armature_223` | `Walk.glb` | `M Neutral Transition Run to Walk Lfoot_fit_Armature.223` | 4.500000 | `locomotion_walk`, `transition`, `left_foot` |
| RUN→WALK R | `Walk/M Neutral Transition Run to Walk Rfoot_fit_Armature_222` | `Walk.glb` | `M Neutral Transition Run to Walk Rfoot_fit_Armature.222` | 4.416667 | `locomotion_walk`, `transition`, `right_foot` |

#### Related transition candidates (inventory completeness, not recommended for this task)

| Runtime path | Source GLB | Duration (s) | Mean root speed (m/s) | Tags |
|---|---|---:|---:|---|
| `Sprint/M Neutral Transition Walk to Sprint Lfoot_fit_Armature_001` | `Sprint.glb` | 3.666667 | 4.1596 | `locomotion_sprint`, `transition`, `left_foot` |
| `Sprint/M Neutral Transition Walk to Sprint Rfoot_fit` | `Sprint.glb` | 3.666667 | 4.1798 | `locomotion_sprint`, `transition`, `right_foot` |
| `Sprint/M Neutral Transition Run to Sprint Lfoot_fit_Armature_003` | `Sprint.glb` | 3.166667 | 5.7182 | `locomotion_sprint`, `transition`, `left_foot` |
| `Sprint/M Neutral Transition Run to Sprint Rfoot_fit_Armature_002` | `Sprint.glb` | 3.000000 | 5.8870 | `locomotion_sprint`, `transition`, `right_foot` |
| `Run/M Neutral Transition Sprint to Run Lfoot_fit_Armature_003` | `Run.glb` | 3.375000 | 4.9968 | `locomotion_run`, `transition`, `left_foot` |
| `Run/M Neutral Transition Sprint to Run Rfoot_fit_Armature_002` | `Run.glb` | 3.250000 | 4.9824 | `locomotion_run`, `transition`, `right_foot` |
| `Walk/M Neutral Transition Sprint to Walk Lfoot_fit_Armature_221` | `Walk.glb` | 4.833333 | 3.2129 | `locomotion_walk`, `transition`, `left_foot` |
| `Walk/M Neutral Transition Sprint to Walk Rfoot_fit_Armature_220` | `Walk.glb` | 4.666667 | 3.0169 | `locomotion_walk`, `transition`, `right_foot` |
| `Crouch/M Neutral Transition Crouch to Stand_fit_Armature_001` | `Crouch.glb` | 2.500000 | ~0 | `locomotion_crouch`, `transition` |
| `Crouch/M Neutral Transition Stand to Crouch_fit` | `Crouch.glb` | 2.500000 | ~0 | `locomotion_crouch`, `transition` |

### 2.3 Directional variants

**None.** No transition clip contains a directional token (`F`, `B`, `L`, `R`, `FL`, `FR`, `BL`, `BR`, `LL`, `LR`, `RL`, `RR`, etc.). The `Lfoot`/`Rfoot` suffix is a lead-foot variant, not a movement direction.

Measured root motion for all four primary candidates is purely `+Z` in animation-root space with `yaw0 = yaw1 = 0 deg` and `yaw_delta = 0 deg`. Sustained WALK/RUN loops do have directional variants, but there are no matching directional gait-transition clips. Therefore any proposal must:

- use these clips only as forward-aligned authored gait changes; and
- rely on the existing authoritative body yaw and `body.global_transform.basis` root-motion conversion for world direction; or
- fall back to the current native crossfade for non-forward transition contexts.

### 2.4 Runtime availability

`M94AnimationTreeController._load_animation_libraries()` loads the default `AnimationLibrary` from each GLB under names `Run`, `Walk`, `Sprint`, `Crouch`, `Idle`. `_build_animation_lookup()` creates runtime paths from database `source_file` and `name`. All four primary transition paths resolve to real `Animation` resources. No database edit is required.

Native search excludes clips tagged `transition`; M9.4 policy data has no transition entries. The clips are therefore addressable but currently unused.

---

## 3. Phase 2 — technical analysis

### 3.1 Measurement method

Raw `Animation` resources were sampled at 60 Hz for root position, root yaw, and all 62 rotation tracks. Database trajectory samples were read at 30 Hz for root velocity and root-local foot positions/velocities.

Pose compatibility is reported as rotation-track RMS and max angle error in degrees across 62 bones. Foot compatibility is reported as the sum of both feet's root-local position errors in metres. “Best phase” means the sampled loop time minimising that metric.

Foot contact was estimated from root-local foot-height minima plus a small height window; because the database has no contact flags and foot samples are skeleton-root-local, these sliding numbers are indicative only. They are compared against the same method applied to the sustained loops.

Reference baselines from the accepted M9.4 probe:

| Baseline | Value |
|---|---:|
| Normal WALK frame-to-frame pose error | 1.2575 deg RMS avg / 7.2342 deg max |
| RUN loop natural step | 3.4524 deg RMS / 15.4737 deg max |
| WALK loop root speed | 1.8314 m/s |
| RUN loop root speed | 4.5785 m/s |
| Current WALK→RUN native crossfade | 0.24 s, 3.3524 deg RMS / 17.1895 deg max, 0.5087 m/s max step |
| Current RUN→WALK native crossfade | 0.24 s, 3.7480 deg RMS / 24.0904 deg max, 0.3180 m/s max step |

### 3.2 Root motion, displacement, and orientation

| Clip | Duration (s) | Start root speed (m/s) | End root speed (m/s) | Root displacement | Yaw |
|---|---:|---:|---:|---|---|
| W2R_L | 3.833333 | 1.8318 | 4.5790 | `+Z 13.6341 m` | 0 deg throughout |
| W2R_R | 3.333333 | 1.8316 | 4.5794 | `+Z 11.1134 m` | 0 deg throughout |
| R2W_L | 4.500000 | 4.5785 | 0.3663 at clip end | `+Z 10.2928 m` full | 0 deg throughout |
| R2W_L trim `4.400 s` | 4.400000 | 4.5785 | **1.8314** | `+Z 10.1707 m` | 0 deg |
| R2W_R | 4.416667 | 4.5762 | 1.2210 at clip end | `+Z 10.6131 m` full | 0 deg throughout |
| R2W_R trim `4.3333 s` | 4.333333 | 4.5762 | **1.8313** | `+Z 10.4910 m` | 0 deg |
| WALK loop | 4.000000 | 1.8314 | 1.8314 | `+Z 7.3257 m` | 0 deg |
| RUN loop | 2.500000 | 4.5785 | 4.5785 | `+Z 11.4463 m` | 0 deg |

All primary candidates are **moving root-motion clips**, not in-place clips. Their speed ramps are authored into the root track:

- W2R_L/R hold `1.8318/1.8316 m/s` for the first frames and settle at `4.5790/4.5794 m/s` for the final ~0.5 s.
- R2W_L/R hold `1.8314/1.8313 m/s` for a substantial final plateau, then decelerate sharply in the last 2–3 frames. This terminal deceleration is an authoring artefact for a transition that should hand off to a moving loop; it must be trimmed.

### 3.3 Pose and foot compatibility with sustained loops

#### WALK → RUN

| Candidate | Start vs WALK loop | End vs RUN loop | Foot positions |
|---|---|---|---|
| **W2R_L** | Best pose phase `0.750 s`: `4.2048 deg RMS / 19.0460 deg max` (worst `hand_r`). At foot-best phase `3.7333 s`: `7.6683 deg RMS / 22.6171 deg max`; foot sum error `0.0644 m`. | Best pose phase `2.000 s`: `0.0133 deg RMS / 0.0791 deg max`; foot sum error `0.0003 m`. | Entry/exit foot sums `0.0644 m` / `0.0003 m`. Exit pose is effectively exact. |
| W2R_R | Best pose phase `1.2167 s`: `5.6692 deg RMS / 19.2228 deg max`; foot sum error `0.0443 m`. | Best pose phase `1.7833 s`: `3.1443 deg RMS / 15.9506 deg max`. Foot-best phase `1.1333 s` has foot sum `0.0495 m` but pose `6.2127 deg RMS / 21.4899 deg max`. | Entry/exit foot sums `0.0443 m` / `0.0495 m`. |

The Lfoot variant has a much stronger exit match and is the recommended WALK→RUN clip. Its entry pose is best matched at WALK loop phase `0.750 s`, not the current C-release phase `0.600 s`; a short entry blend is needed rather than a hard seek.

#### RUN → WALK

| Candidate | Start vs RUN loop | End vs WALK loop | Foot positions |
|---|---|---|---|
| R2W_L | Best pose phase `0.4167 s`: `1.4349 deg RMS / 5.5387 deg max`; foot sum error `0.0913 m`. | Full clip end has wrong speed (`0.3663 m/s`). At trim `4.400 s`, best pose phase `2.7167 s` is `4.2378 deg RMS / 19.0222 deg max`; foot-best phase `3.7333 s` has foot sum `0.0437 m` but pose `13.4513 deg RMS / 40.0761 deg max`. | Pose and foot phases disagree; less reliable. |
| **R2W_R** | Best pose phase `0.6833 s`: `0.8882 deg RMS / 3.2773 deg max`; foot sum error `0.1250 m`. | At trim `4.3333 s`, best pose phase `2.150 s` is `4.8464 deg RMS / 18.5718 deg max`; foot-best phase `2.1333 s` has foot sum `0.0136 m` and pose `5.2254 deg RMS / 21.7163 deg max`. | Pose and foot phases align near `2.13–2.15 s`; recommended. |

The Rfoot variant is recommended for RUN→WALK because its pose-best and foot-best exit phases agree and its trimmed endpoint speed matches the WALK loop.

### 3.4 Foot contact / sliding (indicative)

Values are horizontal foot speed during low-foot windows, in m/s.

| Clip | Left foot max (0.03 / 0.08 m window) | Right foot max (0.03 / 0.08 m window) | Interpretation |
|---|---:|---:|---|
| W2R_L | 1.6317 / 1.8963 | 1.6163 / 1.8697 | Comparable to WALK loop, below RUN loop. |
| W2R_R | 1.6644 / 1.9091 | 1.7895 / 1.7895 | Comparable to WALK loop, below RUN loop. |
| R2W_L | 2.4042 / 2.7663 | 1.7727 / 2.0822 | Above WALK loop, below RUN loop. |
| R2W_R | 1.6391 / 2.4247 | 2.5407 / 2.9439 | Above WALK loop, below RUN loop; right foot needs visual check. |
| WALK loop baseline | 1.7206 / 1.9358 | 1.6672 / 1.9794 | Baseline. |
| RUN loop baseline | 3.6763 (0.08 window) | 4.3003 (0.08 window) | Baseline. |

No candidate shows clearly excessive sliding relative to the RUN loop baseline, but the contact estimator is approximate. Manual foot-slide inspection remains mandatory.

### 3.5 Runtime suitability

| Clip | Suitable? | Reason |
|---|---|---|
| W2R_L | **Yes — primary** | Speed-matched endpoints; near-exact RUN loop exit pose; acceptable sliding; forward-only. |
| W2R_R | Secondary | Speed-matched endpoints; weaker pose match at both ends; keep as fallback variant if Lfoot fails visually. |
| R2W_L | Conditional | Requires trim; pose-best and foot-best exit phases disagree. Use only if Rfoot fails visually. |
| R2W_R | **Yes — primary** | Speed-matched endpoints after trim; pose/foot exit phases align; acceptable sliding. |
| Sprint-related transitions | No, out of scope | Different target speeds and would alter preserved RUN↔SPRINT native behavior. |
| Crouch transitions | No | Posture transition, not gait transition. |

---

## 4. Phase 3 — integration design

### 4.1 Requirements preserved

The design must preserve:

- current IDLE/START/STOP/TURN behavior;
- `WalkNative` and `RunNative` as the sustained WALK/RUN nodes;
- native search as the sustained generator and telemetry source;
- continuous root motion and world direction via the existing body-basis conversion;
- no IDLE or START replay during a gait change;
- RUN-default, `C`-to-WALK, `C` masking Shift, and Shift-to-SPRINT behavior;
- the current `WalkNative <-> RunNative` `0.24 s` crossfade as fallback;
- one `advance(0)`/discard, one `advance(delta)`, one root-motion extraction, and one `move_and_slide()` per accepted switch/tick as governed by `RootMotionIntegrator`.

### 4.2 Proposed state-machine sequence

Add two dynamic one-shot states; do not replace existing states.

```text
Idle -> StartMove -> Run -> RunNative / WalkNative    (unchanged)

WALK -> RUN:
  WalkNative
    --short blend--> WalkToRun
      [Run/M Neutral Transition Walk to Run Lfoot_fit_Armature_001]
      [LOOP_NONE, full 3.833333 s]
    --short blend--> RunNative
      [Run/M Neutral Run Loop F_fit_Armature_114, start_offset = 2.000 s]

RUN -> WALK:
  RunNative
    --short blend--> RunToWalk
      [Walk/M Neutral Transition Run to Walk Rfoot_fit_Armature_222]
      [LOOP_NONE, timeline_length = 4.3333 s]
    --short blend--> WalkNative
      [Walk/M Neutral Walk Loop F_fit_Armature_112, start_offset = 2.133 s]

Fallback / interruption:
  WalkNative <-> RunNative 0.24 s travel-enabled crossfade (unchanged)
  WalkToRun / RunToWalk -> Stop / Turn / Idle / StartMove / opposite native
    short 0.10 s safety exits
```

Timing proposal (initial values to be swept and manually reviewed, not accepted values):

| Edge | Proposed xfade | Rationale |
|---|---:|---|
| `WalkNative -> WalkToRun` | 0.16 s | Smooths WALK `0.600 s` runtime phase to the clip's best `0.750 s` entry pose. |
| `WalkToRun -> RunNative` | 0.16 s | Exit pose is near-exact at `2.000 s`; short blend preserves authored acceleration. |
| `RunNative -> RunToWalk` | 0.16 s | Entry pose error is below 1 deg RMS at best phase; short blend is sufficient. |
| `RunToWalk -> WalkNative` | 0.20 s | Exit pose error is ~4.85 deg RMS; slightly longer blend is conservative. |
| Fallback `WalkNative <-> RunNative` | 0.24 s | Do not change. |
| Safety exits | 0.10 s | Matches existing `M94T_native_exit`. |

### 4.3 Root-motion handling

- Dedicated transition clips are played as normal `AnimationNodeAnimation` clips with the existing `Armature/Skeleton3D:root` track. No root-motion scaling, override, or manual velocity injection.
- On every switch, keep the existing `begin_switch()` -> `advance(0.0)` -> `discard_seek_delta()` ordering so seek deltas never become gameplay velocity.
- On every normal tick, keep one `advance(delta)` followed by one `extract_root_motion()` and the existing `body.global_transform.basis * raw` conversion.
- W2R plays the full clip; its final speed already matches RUN.
- R2W must set `use_custom_timeline = true`, `timeline_length = 4.3333`, and `loop_mode = LOOP_NONE`. Playing to the untrimmed end would introduce a `1.8313 -> 1.2210 m/s` speed dip.
- Destination loop phases are applied through `start_offset` on the handoff request. Raw native search time remains recorded as `search_start_time`; curated phase is recorded as `applied_start_time`.
- During the entry/exit blend, root motion is the AnimationTree's blend of both clips. Because endpoint speeds are matched, this should be continuous; verify with the root-speed telemetry and manual playtest.

### 4.4 Interruptions and input changes

Proposed rules:

1. **Only start a dedicated transition from sustained WALK/RUN.** Require `effective_phase == PHASE_SUSTAINED`, active node `WalkNative` or `RunNative`, no STOP lock, no active START hold, and a valid gait change to RUN/WALK. SPRINT never starts a dedicated transition.
2. **Same target held:** let the transition play to completion; suppress application of new native search results during the transition, but search may continue as telemetry.
3. **Movement released / STOP or TURN phase:** cancel immediately to the reviewed STOP/TURN path through the existing native-exit transition. Do not select IDLE first. STOP lock semantics remain unchanged.
4. **Gait changes again mid-transition (for example WALK→RUN→SPRINT or RUN→WALK→RUN):** cancel the partially played transition and use the existing `WalkNative <-> RunNative` `0.24 s` fallback crossfade to the new target native node. Do not start a second unmeasured transition from a partial pose.
5. **Large direction change / reface during transition:** allow ordinary yaw smoothing; if trajectory classification becomes unsupported or a TURN is selected, cancel via fallback and let the reviewed TURN path own the pose. This is a conservative rule pending manual evidence.
6. **Missing/invalid clip:** fall back to the current crossfade and emit an explicit reason. Never fail to IDLE.

### 4.5 Required code and scene changes (not performed)

All changes would remain under `M9/M9_4/` and would be implementation work requiring separate authorization.

| File | Required change |
|---|---|
| `M9/M9_4/m94_playable_scene.tscn` | Add `WalkToRun` and `RunToWalk` `AnimationNodeAnimation` states; add short entry/exit transitions between them and `WalkNative`/`RunNative`; add safety exits to `Stop`, `Turn`, `Idle`, `StartMove`; keep the existing `0.24 s` travel-enabled `WalkNative <-> RunNative` transition unchanged. |
| `M9/M9_4/m94_animation_controller.gd` | Add state constants and node mapping; add a dedicated one-shot request path (or extend `request_policy`) that sets `loop_mode = LOOP_NONE`, `timeline_length` (including R2W trim), and `start_offset`; preserve the existing `request_clip()` native-search contract. |
| `M9/M9_4/m94_transition_director.gd` | Add gait-transition state machine, completion detection, native-search suppression while active, interruption handlers, and curated loop-phase handoff. Keep `_resolve_gait()` and `_apply_gait_runtime_overrides()` behavior unchanged. |
| `M9/M9_4/runtime_animation_policy_data.gd` | Add curated transition metadata constants: paths, durations, trim time, entry/exit phases, and blend times. Do not reinterpret existing sustained entries. |
| `M9/M9_4/m94_runtime_telemetry.gd` | Expose dedicated transition name/state, elapsed/duration, and handoff phase so manual testers can verify the new path. |
| `M9/M9_4/m9_4_validation.gd` | Update source guards deliberately: current guards assert exactly seven states and one travel-enabled transition. Add tests for one-shot trim, endpoint speeds, no IDLE/START replay, interruption, and fallback. Do not weaken existing guards without review. |
| `M9/M9_4/M9_4_MANUAL_TEST.md` | Add manual scenarios for the dedicated paths and cancellation cases. |

No changes are required to `motion_database.json`, `MotionMatching/animation_database_builder.gd`, `MotionMatching/MotionMatchingSearchController.gd`, search weights, native code, `project.godot`, or the InputMap.

---

## 5. Risks and unresolved questions

1. **No visual acceptance.** Rotation RMS, foot distances, and root speeds do not prove a visually continuous blend. All recommendations are conditional on manual review.
2. **Foot contact is approximate.** The database has no contact flags; low-foot windows and root-local positions were used. The right foot of R2W_R shows the highest estimated sliding and must be watched closely.
3. **R2W terminal deceleration.** If implementation plays the untrimmed clip, speed will dip below WALK speed. Trim support is mandatory.
4. **Entry phase mismatch.** W2R_L's best pose entry is WALK loop `0.750 s`, while the measured C-release phase is `0.600 s`. The proposed entry blend must be validated; a hard seek would snap.
5. **W2R_L pose/foot phase disagreement at entry.** Pose prefers `0.750 s`, foot positions prefer `3.7333 s`. The chosen phase favours pose; manual foot inspection is required.
6. **Longer transitions.** `3.83 s` and `4.33 s` are much longer than the current `0.24 s` crossfade. Short taps, gait reversals, and STOP inputs during the window must be tested.
7. **No directional variants.** Backward/strafe gait changes must keep the fallback. Whether forward-only authored clips look acceptable during gradual yaw changes is unresolved.
8. **Validation assumptions.** Existing source guards hard-code seven states and one travel-enabled transition; they must be updated as part of any implementation, not bypassed.
9. **M9.4 acceptance is still open.** The currently validated native crossfade still requires the user's manual Test 3 retest before M9.4 can be accepted.

---

## 6. Manual test plan

Prerequisite: complete the existing `M9_4_MANUAL_TEST.md` Test 1, Test 2, and especially Test 3 retests first. Do not use this proposal as a substitute for those retests.

### 6.1 Dedicated WALK → RUN

1. Hold `C + WASD` until sustained WALK is on `WalkNative`.
2. Release only `C`; keep movement held.
3. Verify telemetry: no `IDLE` or `START` phase re-entry; `change=WALK>RUN` once; active node becomes `WalkToRun`.
4. Verify the clip path is `Run/M Neutral Transition Walk to Run Lfoot_fit_Armature_001`, one-shot, duration `3.8333 s`.
5. Watch root speed rise from `~1.8314 m/s` to `~4.5785 m/s` continuously; no one-frame jump or mid-transition dip.
6. Verify exit node is `RunNative`, clip `Run/M Neutral Run Loop F_fit_Armature_114`, applied phase `~2.000 s`.
7. Check entry and exit blends for pose pop, IK-hand spike, foot snap, foot slide, yaw jump, and camera pop.

### 6.2 Dedicated RUN → WALK

1. Hold `WASD` until sustained RUN is on `RunNative`.
2. Press and hold `C` without releasing movement.
3. Verify telemetry: no `IDLE` or `START`; `change=RUN>WALK` once; active node becomes `RunToWalk`.
4. Verify the clip path is `Walk/M Neutral Transition Run to Walk Rfoot_fit_Armature_222`, one-shot, trimmed duration `4.3333 s`.
5. Verify root speed falls from `~4.5785 m/s` to `~1.8314 m/s` and stays there at handoff; there must be no terminal deceleration dip.
6. Verify exit node is `WalkNative`, clip `Walk/M Neutral Walk Loop F_fit_Armature_112`, applied phase `~2.133 s`.
7. Watch the right foot specifically for sliding; record any visible slide.

### 6.3 Mid-transition interruption

1. Start a dedicated transition as above.
2. Before it completes, release all movement.
3. Verify a genuine STOP clip plays to completion, STOP lock is acquired and released once, and IDLE is not selected early.
4. Repeat, but re-press `C`, Shift, or a different direction mid-transition.
5. Verify the transition cancels into the correct native node via the `0.24 s` fallback, with no START replay and no one-frame speed jump.

### 6.4 Gait precedence and SPRINT regression

1. From RUN, hold Shift; confirm `NATIVE_SPRINT_HANDOFF` and no dedicated transition.
2. While still holding Shift, press `C`; confirm `gait=WALK`, `masked_sprint=ON`, and no START replay.
3. Release `C` with Shift still held; confirm SPRINT returns through the preserved native path.
4. Confirm no transition clip is selected in any SPRINT case.

### 6.5 Direction change during transition

1. Start a dedicated transition.
2. Gradually change movement direction without triggering a TURN.
3. Verify body yaw and root-motion direction remain continuous and the character does not slide sideways unexpectedly.
4. Trigger a clear reface; verify the reviewed TURN path takes over and no transition clip continues underneath it.

### 6.6 Fallback regression

1. Disable or invalidate the dedicated transition path using a test-only flag.
2. Confirm the existing `WalkNative <-> RunNative` `0.24 s` crossfade still behaves exactly as in current M9.4.
3. Confirm `xfade=0.240`, `search_t`, and `applied_t=1.400` are still logged for WALK→RUN.

### 6.7 Automated regression

Run all seven suites and the standalone scene load. Expected baseline before implementation is `1580 passed, 0 failed`; implementation must preserve or deliberately update the affected guards with reviewed assertions.

---

## 7. Conclusion

The authored GASP-derived transitions are real, loaded, and measured. The strongest candidates are:

- **WALK→RUN:** `Run/M Neutral Transition Walk to Run Lfoot_fit_Armature_001`, full `3.833333 s`.
- **RUN→WALK:** `Walk/M Neutral Transition Run to Walk Rfoot_fit_Armature_222`, trimmed to `4.3333 s`.

Both should be introduced as optional one-shot states with short entry/exit blends and explicit cancellation into the existing native crossfade. The current `WalkNative`/`RunNative` topology and `0.24 s` fallback must remain intact. No implementation is authorized by this audit, and no visual acceptance is claimed.
