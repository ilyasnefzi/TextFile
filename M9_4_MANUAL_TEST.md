# M9.4 Manual Playtest Checklist

**Status:** manual testing checklist only. Automated headless validation lives in `M9/M9_4/m9_4_validation.gd` and does **not** prove visual blend quality.

**Playable scene:** `res://M9/M9_4/m94_playable_scene.tscn`

**Purpose:** visually verify the phase-aware transition feel, root motion, and interruption behavior that cannot be proven by deterministic scripted checks.

---

## 0. Setup

- [ ] Open the project in Godot 4.7.2 and run `M9/M9_4/m94_playable_scene.tscn` directly.
- [ ] Confirm the scene starts with the character standing, facing away from the camera, in a normal idle pose.
- [ ] Confirm there is no T-pose, frozen AnimationTree, camera pop, or visual-character transform offset at startup.
- [ ] Keep the Debugger/Remote scene tree available for inspecting `M94TransitionDirector` and `M94AnimationController` state during the test.

Input actions used by the existing chain: `move_forward`, `move_backward`, `move_left`, `move_right`, `sprint`, `combat_mode`.

Record:

- Tester: ____________________
- Date: ______________________
- Godot build: ________________
- Overall result: PASS / FAIL / NOT RUN

---

## 1. IDLE → START → SUSTAINED

1. Let the character idle for at least 2 seconds.
2. Tap and hold `move_forward`.
3. Keep holding until locomotion is clearly sustained.

- [ ] IDLE remains a calm loop; no foot sliding in place.
- [ ] A distinct reviewed Forward START clip plays before sustained locomotion.
- [ ] START does not look like an unrelated filler or a crouch/run-start substitution.
- [ ] START blends into sustained WALK without a pose pop.
- [ ] The body accelerates smoothly; no instantaneous teleport at the switch frame.
- [ ] Camera keeps following the body; no sudden rotation or offset.
- [ ] Telemetry shows `IDLE → START → SUSTAINED`.

Observed clip/state/path: __________________________________________

Issues: ___________________________________________________________

---

## 2. SUSTAINED → STOP → IDLE

1. From sustained Forward movement, release all movement input.
2. Do not press another movement key.
3. Watch the entire stop and the following idle.

- [ ] A genuine WALK STOP clip plays, not a run stop or idle snap.
- [ ] Full deceleration is visible and the character comes to a physical rest.
- [ ] The STOP clip is not cut short and does not loop.
- [ ] No new input during STOP changes the clip or ends the stop early.
- [ ] IDLE is entered only after the stop clip completes and the body is at rest.
- [ ] No backward slide, snap, or unexpected rotation occurs on the STOP switch frame.
- [ ] Telemetry shows `SUSTAINED → STOP → IDLE` and a single STOP-lock release.

Observed clip/state/duration: ______________________________________

Issues: ___________________________________________________________

---

## 3. Compatible stationary pivot TURN

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

## 4. Compatible moving reface TURN

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

## 5. Unsupported START directions

Test each of Left, Right, Backward-left, and Backward-right from IDLE.

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

## 6. Missing or incompatible STOP fallback

This is primarily automated via `debug_force_missing_stop`; manually verify the resulting presentation only if that branch is exercised.

- [ ] The character does not enter a random transition clip.
- [ ] No STOP lock is acquired.
- [ ] IDLE remains safe and stable.
- [ ] Telemetry reason is `MISSING_STOP_CLIP`.

Issues: ___________________________________________________________

---

## 7. STOP lock interruption attempt

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

## 8. STOP rest/conflict guards

Automated validation forces not-resting and conflicting-phase branches. Visually confirm only when naturally reproducible.

- [ ] If the body is still moving, the lock does not release at STOP playback completion alone.
- [ ] If a conflicting START/TURN phase is forced, the lock does not release early.
- [ ] When the body is at rest and the conflict clears, IDLE resumes normally.

Issues: ___________________________________________________________

---

## 9. Direction changes and combat strafe

1. While sustained, change direction left/right/backward without a large facing reface.
2. Repeat with `combat_mode` active.

- [ ] Normal direction changes stay in sustained locomotion.
- [ ] Combat strafe/backward motion is not misclassified as TURN.
- [ ] No unsupported pivot or reface clip appears.
- [ ] Native sustained search continues to produce smooth locomotion.
- [ ] No foot teleport or root-motion direction inversion is visible.

Issues: ___________________________________________________________

---

## 10. Unsupported turn/speed/curvature contexts

- [ ] Sub-threshold turn yaw does not select a pivot.
- [ ] Combat-mode turn intent does not select a pivot/reface.
- [ ] Unsupported curved/orbit trajectories do not select a turn clip.
- [ ] Unsupported high speed does not select a start/turn clip.
- [ ] Each rejection has an explicit telemetry reason.

Issues: ___________________________________________________________

---

## 11. START interruption by STOP

1. Press forward just long enough to enter START.
2. Release input immediately so STOP begins.

- [ ] START is not restarted or left hanging.
- [ ] STOP acquires the lock and plays its reviewed clip.
- [ ] The visible state sequence is `Idle → Start → Stop → Idle`.
- [ ] No stale sustained search result overrides the STOP clip.

Issues: ___________________________________________________________

---

## 12. Transition event/root-motion sanity

While observing Remote/telemetry:

- [ ] Every accepted clip switch has exactly one `advance_zero`, one discard, one normal advance, one extraction, and one `move_and_slide` in that order.
- [ ] Non-switch ticks do not emit `advance_zero` or discard.
- [ ] Generation increments once per accepted switch.
- [ ] No two clip requests are accepted on the same tick.
- [ ] Forward root motion moves the body along the authoritative body basis, not the visual character basis.

Issues: ___________________________________________________________

---

## 13. Visual red flags — any occurrence is a FAIL

- [ ] T-pose or bind pose visible during any transition.
- [ ] One-frame pose pop or foot snap at START/STOP/TURN boundaries.
- [ ] Frozen character while the camera continues moving.
- [ ] Unexpected 180° rotation during START or STOP.
- [ ] Body slides backward while a forward clip is playing.
- [ ] Camera inherits body yaw or causes feedback rotation.
- [ ] Root motion writes directly to `Visual/Character_01`.
- [ ] Multiple native searches or multiple root-motion readers are active.

---

## 14. Final manual result

- [ ] All required visual scenarios were run.
- [ ] All observed failures were recorded above with repro steps.
- [ ] Automated M9.4 validation was run separately and reported with exact counts.
- [ ] M9.4 is **not** declared accepted by this checklist.

Final manual result: PASS / FAIL / NOT COMPLETE

Signature/notes: ___________________________________________________
