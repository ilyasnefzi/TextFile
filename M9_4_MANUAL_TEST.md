# M9.4 Manual Playtest Checklist

**Status:** manual testing checklist only. Automated headless validation lives in `M9/M9_4/m9_4_validation.gd` and does **not** prove visual blend quality. M9.4 remains **unaccepted until this checklist is completed by a human tester**.

**Latest finding:** manual Test 1 passed the default sequence but reported a clearly visible pose snap at `RUN START → sustained RUN`. A headless pose probe measured the cause: the old speed-only release left START at `0.800 s`, whose pose differs from loop phase `0.000 s` by `24.04 deg` RMS (`87.63 deg` max, worst bone `calf_l`). The sampled START frame at `2.733 s` matches loop phase `0.000 s` at `1.93 deg` RMS (`6.20 deg` max). The same probe found the native switch entering loop phase `1.900 s` and interrupting the configured `0.12 s` `StartMove → Run` crossfade one frame early. The implemented fix releases at the reviewed final START frame, waits for the full crossfade, and aligns the first native handoff to reviewed loop phase `0.000 s`. The user then confirmed the default RUN transition appears visually correct.

**Current finding:** manual Test 2 still reports a noticeable pose snap at `WALK START → sustained WALK`. A separate headless WALK probe measured the same class of cause with independently sampled evidence: the old speed-only rule released START at `0.400 s`, whose pose differs from loop phase `0.000 s` by `24.26 deg` RMS (`91.61 deg` max, worst bone `ik_hand_l`). The sampled START frame at `0.983333 s` matches loop phase `0.000 s` at `0.57 deg` RMS (`2.87 deg` max, worst bone `foot_l`); root speed there is `1.8302 m/s` versus the sustained `1.8314 m/s`. The native switch was applying searched loop phase `3.1667 s`, which differs from loop phase `0.000 s` by `15.28 deg` RMS / `37.81 deg` max. The implemented WALK fix releases at the measured `0.9833 s` frame and aligns the first native handoff to reviewed loop phase `0.000 s`; it does not copy RUN timing. Automated evidence is recorded in `M9_4_ARCHITECTURE_INTERPRETATION.md`; visual acceptance still requires the WALK retest below.

**Playable scene:** `res://M9/M9_4/m94_playable_scene.tscn`

**Purpose:** visually verify the RUN-default gait policy, WALK/SPRINT transitions, phase-aware transition feel, root motion, and interruption behavior that cannot be proven by deterministic scripted checks.

---

## 0. Setup and input map

- [ ] Open the project in Godot 4.7.2 and run `M9/M9_4/m94_playable_scene.tscn` directly.
- [ ] Confirm the scene starts with the character standing, facing away from the camera, in a normal idle pose.
- [ ] Confirm there is no T-pose, frozen AnimationTree, camera pop, or visual-character transform offset at startup.
- [ ] Confirm the on-screen `M9.4 TELEMETRY` overlay is visible by default. Press `F9` to hide or show it. It is read-only and does not affect animation, physics, policy, or search.
- [ ] Keep the Debugger/Remote scene tree available for inspecting `M94TransitionDirector` and `M94AnimationController` state if a telemetry line needs fuller detail.

Input behavior:

| Input | Active gait | Target speed | Notes |
|---|---|---:|---|
| `WASD` only | `RUN` | `4.5 m/s` | Default locomotion. No `C` and no `Shift`. |
| `WASD` + hold `C` | `WALK` | `1.8314 m/s` | Raw key `KEY_C`/keycode `67`, read only inside M9.4. No InputMap action was added. |
| `WASD` + hold `Shift` | `SPRINT` | `6.4 m/s` | Native sustained search remains authoritative. |
| `WASD` + `C` + `Shift` | `WALK` | `1.8314 m/s` | Gait precedence is `WALK > SPRINT > RUN`; `C` masks `Shift`. |

Existing InputMap actions used by the accepted chain: `move_forward`, `move_backward`, `move_left`, `move_right`, `sprint`, `combat_mode`.

The overlay shows live gait, phase, effective phase, policy decision, selected clip, compatibility status, handoff speed delta, logical playback state, AnimationTree node, START hold state, transition reason, phase/state history, and recent transition events. The `eff=` field is the phase actually used by M9.4 policy; during a real-input START it stays `START` after the underlying phase controller has already moved on, by design.

Record:

- Tester: ____________________
- Date: ______________________
- Godot build: ________________
- Overall result: PASS / FAIL / NOT RUN

---

## 1. IDLE → RUN START → RUN (default) — snap-fix retest

This is the primary regression for both the original finding (START was requested but not visibly played) and the reported pose snap at the START → sustained handoff. Retest this section from a clean scene start after the reviewed handoff fix.

1. Let the character idle for at least 2 seconds.
2. Confirm telemetry shows `gait=RUN`, `phase=IDLE`, `eff=IDLE`, `playback=Idle`, `node=Idle`, and the idle clip.
3. Press and hold `move_forward` once. Do not tap-release-tap.
4. Confirm telemetry shows `playback=Start` and `node=StartMove` with the reviewed clip `Run/M Neutral Run Start F Rfoot_fit_Armature_052`, `compat=COMPATIBLE`, and `START hold=ON [RUN]`.
5. Keep holding and watch the whole START clip. The hold must remain `ON` until START elapsed reaches about `2.733 s`; it must **not** release at `0.800 s` as before.
6. Confirm the release event is `start_hold_released reviewed_final_pose`, not `sustained_speed_matched`, with `pose_continuity_reviewed=true` and `elapsed_s` at or just above `2.733`.
7. Confirm the `handoff=` delta is `+0.0000 m/s` and the next reviewed entry is `Run/M Neutral Run Loop F_fit_Armature_114` on node `Run` while logical playback remains `Run`. This is the frame that previously snapped; verify the pose and foot contacts carry across continuously.
8. Continue holding. After the configured `StartMove → Run` crossfade has completed, confirm a `native_handoff_phase_aligned` event followed by `clip_request Run -> RunNative [native_search]` and `node=RunNative`.
9. On the handoff telemetry line, confirm `xfade=0.120`, `aligned=YES`, `applied_t=0.000`, and a nonzero `search_t` (for example `1.867`). The native search result is still recorded; M9.4 deliberately applies reviewed entry phase `0.000 s` so the same loop clip does not jump to search phase.
10. Hold for several seconds of sustained RUN and confirm no recurrent pose, foot, yaw, or root-motion pop.

Expected 60 Hz headless evidence: START request at tick `16`, reviewed release at tick `170` (`elapsed=2.7333`), reviewed loop entry at tick `170`, first native handoff at tick `181` with `crossfade_elapsed_s=0.1833 >= configured_crossfade_s=0.120`, `search_start_time=1.8667`, `applied_start_time=0.0000`, and `reviewed_entry_phase=0.0`. Root speed stays `4.5785–4.5786 m/s` across both switches, accumulated forward root motion remains monotonic, and body yaw stays at `-180 deg`. Wall-clock ticks in the editor may differ; the hold reason, release frame, event order, crossfade completion, applied phase, and zero handoff delta are the required evidence.

- [ ] IDLE remains a calm loop; no foot sliding in place.
- [ ] A distinct reviewed Forward RUN START clip plays through its reviewed acceleration.
- [ ] No WALK START is selected in RUN mode.
- [ ] START does not look like an unrelated filler or a walk/crouch substitution.
- [ ] The visible START pose is held to the reviewed final frame, not replaced after a few frames.
- [ ] START blends into the reviewed RUN loop without a pose pop, foot snap, or knee/calf jump.
- [ ] The `Run → RunNative` switch does not produce a one-frame pose/foot snap even though both states use the same loop clip.
- [ ] Root motion accelerates smoothly; no instantaneous position teleport at either switch frame.
- [ ] Camera keeps following the body; no sudden rotation or offset.
- [ ] Telemetry shows `RUN`, `IDLE → START → SUSTAINED`, `start_hold_released reviewed_final_pose`, reviewed loop entry, `native_handoff_phase_aligned`, then `RunNative`.

Observed clip/state/path: __________________________________________

Observed START hold elapsed / release reason / handoff delta: _______

Observed `xfade` / `aligned` / `search_t` / `applied_t`: ____________

Issues: ___________________________________________________________

---

## 2. IDLE → WALK START → WALK (hold C) — snap-fix retest

This is the primary regression for manual Test 2. Retest from a clean scene start; do not rely on the default RUN result.

1. Let the character idle for at least 2 seconds.
2. Hold `C` first. Confirm telemetry shows `gait=WALK`, `masked_sprint=ON`, `phase=IDLE`, `eff=IDLE`, `playback=Idle`, and `node=Idle`.
3. Press and hold `move_forward` once. Do not tap-release-tap.
4. Confirm telemetry shows `playback=Start` and `node=StartMove` with `Walk/M Neutral Walk Start F Rfoot_fit_Armature_048`, `compat=COMPATIBLE`, and `START hold=ON [WALK]`.
5. Keep holding and watch the whole handoff window. The hold must remain `ON` until START elapsed reaches about `0.983 s`; it must **not** release at `0.400 s` as before.
6. Confirm the release event is `start_hold_released reviewed_final_pose`, with `pose_continuity_reviewed=true` and `elapsed_s` at or just above `0.9833`.
7. Confirm the next reviewed entry is `Walk/M Neutral Walk Loop F_fit_Armature_112` on node `Run` while logical playback remains `Run`. This is the frame that previously snapped; verify the pose, foot contacts, and knee/calf angle carry across continuously.
8. Continue holding. After the configured `StartMove → Run` crossfade has completed, confirm a `native_handoff_phase_aligned` event followed by `clip_request Run -> RunNative [native_search]` and `node=RunNative`.
9. On the handoff telemetry line, confirm `xfade=0.120`, `aligned=YES`, `applied_t=0.000`, and a nonzero `search_t` (for example `3.167`). The native search result is still recorded; M9.4 deliberately applies reviewed loop phase `0.000 s` so the same WALK clip does not jump to search phase.
10. Hold for several seconds of sustained WALK and confirm no recurrent pose, foot, yaw, or root-motion pop.

Expected 60 Hz headless evidence: START release at tick `65` (`elapsed=0.983333`), reviewed loop entry at tick `65`, first native handoff at tick `74` with `crossfade_elapsed_s=0.150000 >= configured_crossfade_s=0.120`, `search_start_time=3.166667`, `applied_start_time=0.000000`, and `reviewed_entry_phase=0.0`. Root speed is `1.8302 m/s` immediately before handoff and `1.8314 m/s` after it, accumulated forward root motion is monotonic, and body yaw stays at `-180 deg`. The recorded clip-end `handoff=` delta remains `+0.3662 m/s` metadata; it is not a physical velocity jump. Wall-clock ticks in the editor may differ; the hold reason, release frame, event order, crossfade completion, applied phase, and pose continuity are the required evidence.

- [ ] Telemetry shows `gait=WALK` and `masked_sprint=ON`.
- [ ] `Walk/M Neutral Walk Start F Rfoot_fit_Armature_048` plays on `StartMove`.
- [ ] `START hold=ON [WALK]` holds to the measured pose frame, not the old speed release.
- [ ] `start_hold_released reviewed_final_pose` is observed at about `0.983 s` with reviewed pose continuity.
- [ ] `Walk/M Neutral Walk Loop F_fit_Armature_112` is the reviewed sustained entry on node `Run`.
- [ ] The `WALK START → WALK` handoff has no visible pose snap, foot snap, or knee/calf jump.
- [ ] The `Run → RunNative` switch has no one-frame pose/foot snap.
- [ ] Root speed, accumulated motion, and yaw remain continuous through both switches.
- [ ] Native telemetry shows `xfade=0.120`, `aligned=YES`, and `applied_t=0.000`.
- [ ] `handoff=` still shows the recorded `+0.3662 m/s` and `status=HANDOFF_SPEED_MATCHED`.
- [ ] Native sustained playback still reaches `RunNative`.
- [ ] No RUN START or SPRINT clip appears.

Observed clip/state/handoff: _______________________________________

Observed START hold elapsed / release reason / handoff delta: _______

Observed `xfade` / `aligned` / `search_t` / `applied_t`: ____________

Issues: ___________________________________________________________

---

## 3. WALK release while moving → RUN

1. Hold `C` + `WASD` until sustained WALK is playing.
2. Keep movement held and release `C` only.
3. Observe the next 12–30 frames.

- [ ] Active gait changes from `WALK` to `RUN` exactly once; telemetry shows `change=WALK>RUN`.
- [ ] Phase sequence does **not** return to `IDLE`.
- [ ] Phase sequence does **not** return to `START`; no START clip is replayed.
- [ ] Logical playback remains `Run`; native sustained continues on `RunNative`.
- [ ] Prediction target returns to `4.5 m/s` and sustained thresholds return to RUN values.
- [ ] No clip flicker or one-frame pose pop at the gait switch.
- [ ] A visible acceleration toward RUN speed is acceptable; an instantaneous teleport is a defect.

Issues: ___________________________________________________________

---

## 4. RUN ↔ SPRINT without START replay

1. Hold `WASD` until sustained RUN is playing.
2. Hold `Shift` without releasing movement.
3. Observe RUN → SPRINT, then release `Shift` and observe SPRINT → RUN.

- [ ] RUN → SPRINT selects `gait=SPRINT` and `last_policy_reason=NATIVE_SPRINT_HANDOFF`.
- [ ] No `Start` clip request, no `IDLE` phase, and no `START` phase re-entry in either direction.
- [ ] Native sustained playback stays on `RunNative`.
- [ ] Sprint target is `6.4 m/s`; returning to RUN restores `4.5 m/s`.
- [ ] No dedicated SPRINT START or SPRINT STOP clip is invented.
- [ ] No pose pop at either gait switch.

Issues: ___________________________________________________________

---

## 5. WALK masks SPRINT

1. Hold `Shift` + `WASD` until SPRINT is active.
2. While still holding `Shift` and `WASD`, press and hold `C`.
3. Release `C`, then release `Shift`.

- [ ] While `C` is held, telemetry shows `gait=WALK` and `masked_sprint=ON`.
- [ ] The accepted intent controller's sprint flag is masked off while WALK is active.
- [ ] Target speed is `1.8314 m/s`, not `6.4 m/s`.
- [ ] No START replay or IDLE return occurs.
- [ ] Releasing `C` with `Shift` still held returns to SPRINT, not RUN.

Issues: ___________________________________________________________

---

## 6. Forward RUN chain compatibility

1. From IDLE, press `WASD` forward and hold through START, sustained entry, and native sustained.
2. Inspect telemetry at each handoff.

- [ ] `compat=COMPATIBLE` for START, sustained entry, and STOP.
- [ ] `visual_claim=YES` is shown only for this fully compatible forward chain.
- [ ] `status=HANDOFF_SPEED_MATCHED` and `handoff=+0.0000 m/s`.
- [ ] `stop_delta=+0.0000 m/s` at the reviewed RUN STOP handoff.
- [ ] No pose pop, foot snap, or root-motion spike at either switch.

Issues: ___________________________________________________________

---

## 7. Conditional RUN directions

For each of Backward, Forward-right (`D+W`), Forward-left (`A+W`), Right (`D`), Backward-left (`A+S`), and Backward-right (`D+S`):

1. From IDLE, press and hold the direction with no `C` and no `Shift`.
2. Confirm a reviewed RUN START is selected and telemetry reports the measured direction.
3. Hold through sustained entry and release to STOP.

- [ ] `compat=CONDITIONAL` and `visual_claim=NO`.
- [ ] `last_policy_reason=CONDITIONAL_SPEED_DELTA`.
- [ ] `handoff=` matches the measured delta for that direction; it is nonzero.
- [ ] A curated START, sustained entry, and STOP path are selected; no unrelated clip is substituted.
- [ ] No visual-compatibility claim is made by the overlay.
- [ ] Any visible pose discontinuity is recorded as a defect for that direction.

| Direction | Clip path observed | Compatibility | Handoff delta | Visual result |
|---|---|---|---:|---|
| Backward | __________________ | CONDITIONAL | _________ | P / F |
| Forward-right | __________________ | CONDITIONAL | _________ | P / F |
| Forward-left | __________________ | CONDITIONAL | _________ | P / F |
| Right | __________________ | CONDITIONAL | _________ | P / F |
| Backward-left | __________________ | CONDITIONAL | _________ | P / F |
| Backward-right | __________________ | CONDITIONAL | _________ | P / F |

Issues: ___________________________________________________________

---

## 8. Left RUN is unsupported for handoff

1. From IDLE, press and hold `move_left` with no `C` and no `Shift`.
2. Hold through sustained locomotion, then release.

- [ ] No reviewed Left RUN START or sustained entry clip is selected.
- [ ] `last_policy_reason=UNSUPPORTED_RUN_HANDOFF` and `visual_claim=NO`.
- [ ] Native sustained playback still owns the direction.
- [ ] On release, the reviewed Left RUN STOP (`Run/M Neutral Run Stop RL Rfoot_fit_Armature_022`) is selected instead of snapping to IDLE.
- [ ] No T-pose, freeze, or unexpected root motion occurs.

Issues: ___________________________________________________________

---

## 9. SUSTAINED → STOP → IDLE

1. From sustained Forward RUN or deliberate WALK, release all movement input.
2. Do not press another movement key.
3. Watch the entire stop and the following idle.

- [ ] A genuine reviewed STOP clip for the active gait/direction plays.
- [ ] Full deceleration is visible and the character comes to a physical rest.
- [ ] The STOP clip is not cut short and does not loop.
- [ ] No new input during STOP changes the clip or ends the stop early.
- [ ] IDLE is entered only after the stop clip completes and the body is at rest.
- [ ] No backward slide, snap, or unexpected rotation occurs on the STOP switch frame.
- [ ] Telemetry shows `SUSTAINED → STOP → IDLE` and a single STOP-lock release.
- [ ] For SPRINT, the overlay explicitly shows the RUN STOP fallback (`NATIVE_SPRINT_STOP_FALLBACK`), not a claim of a dedicated sprint stop.

Observed clip/state/duration: ______________________________________

Issues: ___________________________________________________________

---

## 10. Compatible stationary pivot TURN

1. From IDLE, rotate the camera/intent to produce a clear left or right turn of roughly 90°.
2. Hold still except for the turn input.
3. Return to neutral after the pivot.

- [ ] A reviewed standing pivot clip is selected only when a compatible angle/sign is available.
- [ ] Pivot rotation matches the requested sign; no wrong-way turn.
- [ ] Feet stay near the ground; no visible root-motion spike.
- [ ] After the pivot, the character settles back into IDLE or sustained motion as appropriate.
- [ ] No combat strafe or ordinary direction change is misclassified as a pivot.

Observed turn clip/sign/angle: _____________________________________

Issues: ___________________________________________________________

---

## 11. Compatible moving reface TURN

1. From sustained movement, request a large reface near 180° while still moving.
2. Hold movement through the reface.
3. Continue into sustained locomotion.

- [ ] A reviewed translating reface clip is selected only for the large moving reface context.
- [ ] Translation and rotation feel continuous; no sudden turn-in-place.
- [ ] The character exits into sustained locomotion without a pose freeze or T-pose.
- [ ] Final facing matches the requested reface direction.
- [ ] Telemetry shows `SUSTAINED → TURN → SUSTAINED`.

Observed reface clip/sign/duration: ________________________________

Issues: ___________________________________________________________

---

## 12. Unsupported WALK START directions

With `C` held from IDLE, test each of Left, Right, Backward-left, and Backward-right.

- [ ] No start clip is substituted for these unsupported standing starts.
- [ ] The character remains in safe IDLE with no filler animation.
- [ ] Telemetry reason is `UNSUPPORTED` for each case.
- [ ] No T-pose, freeze, or unexpected root motion occurs.

| Direction | Clip changed? | Reason shown | Result |
|---|---|---|---|
| Left | Y / N | __________ | P / F |
| Right | Y / N | __________ | P / F |
| Backward-left | Y / N | __________ | P / F |
| Backward-right | Y / N | __________ | P / F |

Issues: ___________________________________________________________

---

## 13. Missing or incompatible STOP fallback

This is primarily automated via `debug_force_missing_stop`; manually verify the resulting presentation only if that branch is exercised.

- [ ] The character does not enter a random transition clip.
- [ ] No STOP lock is acquired.
- [ ] IDLE remains safe and stable.
- [ ] Telemetry reason is `MISSING_STOP_CLIP`.

Issues: ___________________________________________________________

---

## 14. STOP lock interruption attempt

1. Begin a genuine Forward STOP.
2. Immediately try a new START, a turn, and IDLE input before the stop completes.
3. Release all input and let the stop finish.

- [ ] Interruption attempts emit `STOP_LOCK_SUPPRESSED`.
- [ ] The STOP clip keeps playing to completion.
- [ ] IDLE is not selected early.
- [ ] After release, a new command works normally.
- [ ] No duplicate clip requests or rapid flicker occurs.

Issues: ___________________________________________________________

---

## 15. STOP rest/conflict guards

Automated validation forces not-resting and conflicting-phase branches. Visually confirm only when naturally reproducible.

- [ ] If the body is still moving, the lock does not release at STOP playback completion alone.
- [ ] If a conflicting START/TURN phase is forced, the lock does not release early.
- [ ] When the body is at rest and the conflict clears, IDLE resumes normally.

Issues: ___________________________________________________________

---

## 16. Direction changes and combat strafe

1. While sustained, change direction left/right/backward without a large facing reface.
2. Repeat with `combat_mode` active.

- [ ] Normal direction changes stay in sustained locomotion.
- [ ] Combat strafe/backward motion is not misclassified as TURN.
- [ ] No unsupported pivot or reface clip appears.
- [ ] Native sustained search continues to produce smooth locomotion.
- [ ] No foot teleport or root-motion direction inversion is visible.

Issues: ___________________________________________________________

---

## 17. Unsupported turn/speed/curvature contexts

- [ ] Sub-threshold turn yaw does not select a pivot.
- [ ] Combat-mode turn intent does not select a pivot/reface.
- [ ] Unsupported curved/orbit trajectories do not select a turn clip.
- [ ] Unsupported high speed does not select a start/turn clip.
- [ ] Each rejection has an explicit telemetry reason.

Issues: ___________________________________________________________

---

## 18. START interruption by STOP

1. Press forward just long enough to enter START.
2. Release input immediately so STOP begins.

- [ ] START is not restarted or left hanging.
- [ ] STOP acquires the lock and plays its reviewed clip.
- [ ] The visible state sequence is `Idle → Start → Stop → Idle`.
- [ ] No stale sustained search result overrides the STOP clip.

Issues: ___________________________________________________________

---

## 19. Transition event/root-motion sanity

While observing Remote/telemetry:

- [ ] Every accepted clip switch has exactly one `advance_zero`, one discard, one normal advance, one extraction, and one `move_and_slide` in that order.
- [ ] Non-switch ticks do not emit `advance_zero` or discard.
- [ ] Generation increments once per accepted switch.
- [ ] No two clip requests are accepted on the same tick.
- [ ] Forward root motion moves the body along the authoritative body basis, not the visual character basis.

Issues: ___________________________________________________________

---

## 20. Visual red flags — any occurrence is a FAIL

- [ ] T-pose or bind pose visible during any transition.
- [ ] One-frame pose pop or foot snap at START/STOP/TURN boundaries.
- [ ] Frozen character while the camera continues moving.
- [ ] Unexpected 180° rotation during START or STOP.
- [ ] Body slides backward while a forward clip is playing.
- [ ] Camera inherits body yaw or causes feedback rotation.
- [ ] Root motion writes directly to `Visual/Character_01`.
- [ ] Multiple native searches or multiple root-motion readers are active.
- [ ] A conditional RUN direction is presented as visually verified.
- [ ] A WALK clip is used while `gait=RUN` or `gait=SPRINT`.

---

## 21. Final manual result

- [ ] All required visual scenarios were run.
- [ ] All observed failures were recorded above with repro steps.
- [ ] Automated M9.4 validation was run separately and reported with exact counts.
- [ ] M9.4 is **not** declared accepted by this checklist.

Final manual result: PASS / FAIL / NOT COMPLETE

Signature/notes: ___________________________________________________
