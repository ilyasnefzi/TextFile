# Milestone 7 - Animation Asset Intelligence and Catalog

Diagnostic only. No production script, scene, database, search setting,
C++ source or binary was changed by this diagnostic.

Database: `user://motion_database.json`
SHA-256: `e1c90ad212812b673c8b0da90d6e73b0e371988e46559364be9ff1e04ecfe4dd`
Clips measured: 718
Coordinate convention: Forward `+Z`, Backward `-Z`, Left `-X`, Right `+X`.

## Measurement method

- Root displacement: sampled root position at end minus start, cross-checked against the database `displacement` field.
- Average horizontal speed: horizontal displacement / duration.
- Mean/peak/initial/final speed: finite-difference root velocity from the database samples, horizontal magnitude.
- Movement direction: root velocity rotated into the initial root-facing frame using measured parent yaw; resultant strength below 0.25 is marked AMBIGUOUS/CURVED, and disagreeing thirds are marked MIXED.
- Root rotation: signed shortest yaw of the final relative root quaternion; total angular displacement is the sum of absolute per-sample yaw deltas.
- Maximum angular velocity: largest absolute per-sample yaw delta / delta time.
- Clean loop: horizontal displacement <= 0.050 m, final rotation <= 5.0 deg, endpoint speed delta <= 0.50 m/s.
- Category classification uses measured speed, acceleration trend, rotation, radius and displacement. Animation names/tags/source supply an *apparent* hint only; Reface additionally requires measured rotation >= 45 deg, and Shuffle is reported only as a hint-compatible category because root motion alone cannot prove footwork style.

## Category coverage summary

| Measured category | Clips | Native-eligible |
|---|---:|---:|
| Idle | 23 | 0 |
| Walk | 191 | 13 |
| Run | 75 | 16 |
| Sprint | 17 | 5 |
| Crouch | 131 | 0 |
| Start | 60 | 0 |
| Stop | 98 | 3 |
| Turn | 5 | 0 |
| Pivot | 4 | 0 |
| Reface | 30 | 0 |
| Shuffle | 14 | 0 |
| Circle/curved locomotion | 70 | 0 |
| Other | 0 | 0 |

See `animation_catalog_coverage_tables.md` for full directional tables.

## Recommended candidates


### Idle

| Clip | Speed | Start -> End | Rotation | Displacement | Direction | Eligible |
|---|---:|---:|---:|---:|---|---|
| M Neutral Crouch Idle Loop_fit_Armature_017 | 0.005 | 0.003 -> 0.001 | 0.0 deg | 0.000 m | NONE | false |
| M Neutral Stand Idle Break v02_fit_Armature_013 | 0.005 | 0.006 -> 0.003 | 0.0 deg | 0.000 m | NONE | false |
| M Neutral Stand Idle Loop_fit_Armature_008 | 0.006 | 0.011 -> 0.001 | 0.0 deg | 0.000 m | NONE | false |
| M Neutral Crouch Idle Break v01_fit_Armature_022 | 0.017 | 0.012 -> 0.011 | 0.0 deg | 0.000 m | NONE | false |
| M Neutral Stand Idle Break v01_fit_Armature_014 | 0.017 | 0.009 -> 0.005 | 0.0 deg | 0.000 m | NONE | false |
| M Neutral Crouch Idle Break v05_fit_Armature_018 | 0.018 | 0.005 -> 0.003 | 0.0 deg | 0.000 m | Forward-right | false |
| M Neutral Stand Idle Break v05_fit_Armature_010 | 0.024 | 0.011 -> 0.009 | 0.0 deg | 0.000 m | Forward | false |
| M Neutral Stand Idle Break v04_fit_Armature_011 | 0.024 | 0.011 -> 0.009 | 0.0 deg | 0.000 m | Forward | false |
| M Neutral Stand Idle Break v03_fit_Armature_012 | 0.025 | 0.010 -> 0.011 | 0.0 deg | 0.000 m | Forward-right | false |
| M Neutral Crouch Idle Break v03_fit_Armature_020 | 0.027 | 0.015 -> 0.024 | 0.0 deg | 0.000 m | AMBIGUOUS | false |
| M Neutral Crouch Idle Break v04_fit_Armature_019 | 0.034 | 0.019 -> 0.006 | 0.0 deg | 0.000 m | Forward-right | false |
| M Neutral Stand Idle Break v06_fit_Armature_009 | 0.058 | 0.005 -> 0.001 | 0.0 deg | 0.000 m | AMBIGUOUS | false |

### Start

| Clip | Speed | Start -> End | Rotation | Displacement | Direction | Eligible |
|---|---:|---:|---:|---:|---|---|
| M Neutral Sprint Start FR Rfoot_fit_Armature_018 | 4.918 | 0.000 -> 6.410 | 0.0 deg | 12.352 m | Forward-left | false |
| M Neutral Sprint Start F Lfoot_fit_Armature_023 | 4.914 | 0.000 -> 6.408 | 0.0 deg | 12.342 m | Forward | false |
| M Neutral Sprint Start FR Lfoot_fit_Armature_019 | 4.905 | 0.000 -> 5.128 | 0.0 deg | 12.548 m | Forward-left | false |
| M Neutral Run Start F Rfoot_fit_Armature_052 | 3.914 | 0.000 -> 4.579 | 0.0 deg | 11.165 m | Forward | false |
| M Neutral Run Start FR Lfoot_fit_Armature_049 | 3.873 | 0.000 -> 3.663 | 0.0 deg | 10.556 m | Forward-left | false |
| M Neutral Sprint Start FL Lfoot_fit_Armature_021 | 4.832 | 0.000 -> 3.663 | 0.0 deg | 11.937 m | Forward-right | false |
| M Neutral Run Start FL Lfoot_fit_Armature_051 | 3.827 | 0.000 -> 3.663 | 0.0 deg | 9.792 m | Forward-right | false |
| M Neutral Run Start LL Lfoot_fit_Armature_047 | 2.820 | 0.000 -> 3.205 | 0.0 deg | 7.091 m | Right | false |
| M Neutral Run Start FL Rfoot_fit_Armature_050 | 3.911 | 0.000 -> 3.052 | 0.0 deg | 11.469 m | Forward-right | false |
| M Neutral Run Start F Lfoot_fit_Armature_053 | 3.829 | 0.000 -> 2.616 | 0.0 deg | 10.095 m | Forward | false |
| M Neutral Run Start FR Rfoot_fit_Armature_048 | 3.830 | 0.000 -> 2.616 | 0.0 deg | 10.098 m | Forward-left | false |
| M Neutral Run Start BR Rfoot_fit_Armature_054 | 2.487 | 0.000 -> 2.198 | 0.0 deg | 7.194 m | Backward-left | false |

### Stop

| Clip | Speed | Start -> End | Rotation | Displacement | Direction | Eligible |
|---|---:|---:|---:|---:|---|---|
| M Neutral Sprint Stop F Lfoot_fit_Armature_017 | 0.944 | 6.410 -> 0.000 | 0.0 deg | 4.361 m | Forward | false |
| M Neutral Sprint Stop FL Lfoot_fit_Armature_015 | 0.944 | 6.410 -> 0.000 | 0.0 deg | 4.361 m | Forward-right | false |
| M Neutral Sprint Stop FR Lfoot_fit_Armature_013 | 0.944 | 6.410 -> 0.000 | 0.0 deg | 4.361 m | Forward-left | false |
| M Neutral Sprint Stop F Rfoot_fit_Armature_016 | 0.987 | 6.407 -> 0.000 | 0.0 deg | 4.567 m | Forward | false |
| M Neutral Sprint Stop FL Rfoot_fit_Armature_014 | 0.987 | 6.407 -> 0.000 | 0.0 deg | 4.567 m | Forward-right | false |
| M Neutral Sprint Stop FR Rfoot_fit_Armature_012 | 0.987 | 6.407 -> 0.000 | 0.0 deg | 4.567 m | Forward-left | false |
| M Neutral Run Stop FR Rfoot_fit_Armature_028 | 0.939 | 4.671 -> 0.000 | 0.0 deg | 3.335 m | Forward-left | false |
| M Neutral Run Stop FL Lfoot_fit_Armature_031 | 1.011 | 4.588 -> 0.000 | 0.0 deg | 3.429 m | Forward-right | false |
| M Neutral Run Stop FL Rfoot_fit_Armature_030 | 0.910 | 4.587 -> 0.000 | 0.0 deg | 3.505 m | Forward-right | false |
| M Neutral Run Stop F Lfoot_fit_Armature_033 | 0.957 | 4.579 -> 0.000 | 0.0 deg | 3.848 m | Forward | false |
| M Neutral Run Stop F Rfoot_fit_Armature_032 | 0.957 | 4.579 -> 0.000 | 0.0 deg | 3.848 m | Forward | false |
| M Neutral Run Stop FR Lfoot_fit_Armature_029 | 1.008 | 4.575 -> 0.000 | 0.0 deg | 3.485 m | Forward-left | false |

### Turn/Reface

| Clip | Speed | Start -> End | Rotation | Displacement | Direction | Eligible |
|---|---:|---:|---:|---:|---|---|
| M Neutral Crouch Idle Turn 090 R_fit_Armature_114 | 0.099 | 0.056 -> 0.040 | 90.0 deg | 0.099 m | MIXED | false |
| M Neutral Crouch Idle Turn 090 L_fit_Armature_115 | 0.120 | 0.143 -> 0.008 | 90.0 deg | 0.100 m | CURVED/CHANGING | false |
| M Neutral Crouch Reface Start B R 180_fit_Armature_066 | 1.546 | 0.050 -> 1.099 | 180.0 deg | 5.048 m | Forward | false |
| M Neutral Crouch Reface Start B L 180_fit_Armature_068 | 1.545 | 0.041 -> 0.942 | 180.0 deg | 5.103 m | Forward | false |
| M Neutral Run Reface Start B R 180_fit_Armature_069 | 2.155 | 0.288 -> 1.831 | 180.0 deg | 5.239 m | MIXED | false |
| M Neutral Run Reface Start B L 180_fit_Armature_071 | 2.288 | 0.351 -> 1.831 | 180.0 deg | 5.561 m | Forward | false |
| M Neutral Crouch Reface Start F R 180_fit_Armature_062 | 1.892 | 0.016 -> 2.060 | 180.0 deg | 6.020 m | Backward | false |
| M Neutral Crouch Reface Start F L 180_fit_Armature_064 | 1.885 | 0.020 -> 1.374 | 180.0 deg | 6.155 m | MIXED | false |
| M Neutral Walk Reface Start B L 180_fit_Armature_072 | 1.328 | 0.021 -> 1.374 | 180.0 deg | 6.659 m | Forward | false |
| M Neutral Walk Reface Start B R 180_fit_Armature_070 | 1.328 | 0.021 -> 1.374 | 180.0 deg | 6.659 m | Forward | false |
| M Neutral Crouch Idle Turn 045 R_fit_Armature_116 | 0.084 | 0.321 -> 0.006 | 45.0 deg | 0.054 m | Forward-right | false |
| M Neutral Crouch Idle Turn 045 L_fit_Armature_117 | 0.100 | 0.141 -> 0.012 | 45.0 deg | 0.054 m | CURVED/CHANGING | false |

### Pivot

| Clip | Speed | Start -> End | Rotation | Displacement | Direction | Eligible |
|---|---:|---:|---:|---:|---|---|
| M Neutral Crouch Idle Turn 180 L_fit_Armature_111 | 0.182 | 0.405 -> 0.005 | 180.0 deg | 0.141 m | CURVED/CHANGING | false |
| M Neutral Crouch Idle Turn 180 R_fit_Armature_110 | 0.171 | 0.368 -> 0.048 | 180.0 deg | 0.141 m | Backward-right | false |
| M Neutral Crouch Idle Turn 135 L_fit_Armature_113 | 0.102 | 0.249 -> 0.012 | 135.0 deg | 0.130 m | Backward | false |
| M Neutral Crouch Idle Turn 135 R_fit_Armature_112 | 0.091 | 0.359 -> 0.003 | 135.0 deg | 0.130 m | Forward-right | false |

## Directional coverage gaps

- Missing Start directions: []
- Missing Stop directions: []
- Missing in both Start and Stop: []

## Duplicate detection

- Exact duplicate groups (rounded to 1e-6): 1
- Mirrored pairs: 100
- Near-identical pairs: 33
- Small timing/root-motion-change pairs: 167

### Mirrored pairs (first 30)

| A | B | dDuration | PosRMS | SpeedMAE | YawMAE |
|---|---|---:|---:|---:|---:|
| M Neutral Run Arc Tight L_fit_Armature_226 | M Neutral Run Arc Tight R_fit_Armature_225 | 0.0000 | 0.0370 | 0.0340 | 0.00 |
| M Neutral Run Arc Wide L_fit_Armature_224 | M Neutral Run Arc Wide R_fit_Armature_223 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Hourglass FL RL Rfoot_fit_Armature_147 | M Neutral Run Hourglass FR LR Lfoot_fit_Armature_142 | 0.0000 | 0.0336 | 0.0140 | 0.00 |
| M Neutral Run Loop BL_fit_Armature_116 | M Neutral Run Loop BR_fit_Armature_115 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Loop BL_fit_Armature_116 | M Neutral Run Loop Strafe BR_fit_Armature_103 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Loop F L 20_fit_Armature_113 | M Neutral Run Loop F R 20_fit_Armature_112 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Loop FL_fit_Armature_111 | M Neutral Run Loop FR_fit_Armature_110 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Loop FR_fit_Armature_110 | M Neutral Run Loop Strafe FL_fit_Armature_102 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Loop LL_fit_Armature_109 | M Neutral Run Loop RR_fit_Armature_105 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Loop LR_fit_Armature_108 | M Neutral Run Loop RR_fit_Armature_105 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Arc F Small L_fit_Armature_219 | M Neutral Walk Arc F Small R_fit_Armature_218 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Arc F Tight L_fit_Armature_217 | M Neutral Walk Arc F Tight R_fit_Armature_216 | 0.0000 | 0.0590 | 0.0341 | 0.00 |
| M Neutral Walk Arc F Wide L_fit_Armature_215 | M Neutral Walk Arc F Wide R_fit_Armature_214 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Box LL F Lfoot_fit_Armature_195 | M Neutral Walk Box RR F Lfoot_fit_Armature_183 | 0.0000 | 0.0115 | 0.0020 | 0.00 |
| M Neutral Walk Box LR B Lfoot_fit_Armature_193 | M Neutral Walk Box RL B Rfoot_fit_Armature_188 | 0.0000 | 0.0544 | 0.0022 | 0.00 |
| M Neutral Walk Box LR F Lfoot_fit_Armature_191 | M Neutral Walk Box RL F Rfoot_fit_Armature_186 | 0.0000 | 0.0184 | 0.0882 | 0.00 |
| M Neutral Walk Box LR F Lfoot_fit_Armature_191 | M Neutral Walk Box RR F Rfoot_fit_Armature_182 | 0.0000 | 0.0473 | 0.0942 | 0.00 |
| M Neutral Walk Diamond BL F Lfoot_fit_Armature_173 | M Neutral Walk Diamond BR F Rfoot_fit_Armature_166 | 0.0000 | 0.0716 | 0.0864 | 0.00 |
| M Neutral Walk Diamond BL F Rfoot_fit_Armature_172 | M Neutral Walk Diamond BR F Rfoot_fit_Armature_166 | 0.0000 | 0.0099 | 0.0043 | 0.00 |
| M Neutral Walk Diamond FL B Lfoot_fit_Armature_159 | M Neutral Walk Diamond FR B Lfoot_fit_Armature_153 | 0.0000 | 0.0365 | 0.0133 | 0.00 |
| M Neutral Walk Hourglass BL RR Lfoot_fit_Armature_145 | M Neutral Walk Hourglass BR LL Lfoot_fit_Armature_143 | 0.0000 | 0.0579 | 0.1288 | 0.00 |
| M Neutral Walk Hourglass FL RR Rfoot_fit_Armature_136 | M Neutral Walk Hourglass FR LR Rfoot_fit_Armature_132 | 0.0000 | 0.0739 | 0.0066 | 0.00 |
| M Neutral Walk Hourglass LL FR Lfoot_fit_Armature_129 | M Neutral Walk Hourglass RL FL Lfoot_fit_Armature_121 | 0.0000 | 0.0619 | 0.0334 | 0.00 |
| M Neutral Walk Hourglass LL FR Lfoot_fit_Armature_129 | M Neutral Walk Hourglass RR FL Rfoot_fit_Armature_116 | 0.0000 | 0.0386 | 0.0226 | 0.00 |
| M Neutral Walk Loop BL_fit_Armature_114 | M Neutral Walk Loop BR_fit_Armature_113 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Loop F L 20_fit_Armature_111 | M Neutral Walk Loop F R 20_fit_Armature_110 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Loop FL_fit_Armature_109 | M Neutral Walk Loop FR_fit_Armature_108 | 0.0000 | 0.0002 | 0.0001 | 0.00 |
| M Neutral Walk Loop LL_fit_Armature_107 | M Neutral Walk Loop RR_fit_Armature_103 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Loop LR_fit_Armature_106 | M Neutral Walk Loop RL_fit_Armature_104 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Pivot F B Lfoot_fit_Armature_095 | M Neutral Walk Pivot F B Rfoot_fit_Armature_094 | 0.0000 | 0.0561 | 0.0269 | 0.00 |

### Near-identical pairs (first 30)

| A | B | dDuration | PosRMS | SpeedMAE | YawMAE |
|---|---|---:|---:|---:|---:|
| M Neutral Run Box RL B Rfoot_fit_Armature_197 | M Neutral Run Box RR B Lfoot_fit_Armature_194 | 0.0000 | 0.0002 | 0.0017 | 0.00 |
| M Neutral Run Loop BR_fit_Armature_115 | M Neutral Run Loop Strafe BR_fit_Armature_103 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Loop FL_fit_Armature_111 | M Neutral Run Loop Strafe FL_fit_Armature_102 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Loop LL_fit_Armature_109 | M Neutral Run Loop LR_fit_Armature_108 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Run Stop F Lfoot_fit_Armature_033 | M Neutral Run Stop F Rfoot_fit_Armature_032 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Box B RR Lfoot_fit_Armature_207 | M Neutral Walk Box B RR Rfoot_fit_Armature_206 | 0.0000 | 0.0472 | 0.0032 | 0.00 |
| M Neutral Walk Box RL B Lfoot_fit_Armature_189 | M Neutral Walk Box RR B Lfoot_fit_Armature_185 | 0.0000 | 0.0498 | 0.0004 | 0.00 |
| M Neutral Walk Box RL B Lfoot_fit_Armature_189 | M Neutral Walk Box RR B Rfoot_fit_Armature_184 | 0.0000 | 0.0245 | 0.0004 | 0.00 |
| M Neutral Walk Box RL F Rfoot_fit_Armature_186 | M Neutral Walk Box RR F Rfoot_fit_Armature_182 | 0.0000 | 0.0289 | 0.0061 | 0.00 |
| M Neutral Walk Diamond F BR Lfoot_fit_Armature_161 | M Neutral Walk Diamond F BR Rfoot_fit_Armature_160 | 0.0000 | 0.0319 | 0.0162 | 0.00 |
| M Neutral Walk Diamond FL FR Lfoot_fit_Armature_155 | M Neutral Walk Diamond FL FR Rfoot_fit_Armature_154 | 0.0000 | 0.0016 | 0.0870 | 0.00 |
| M Neutral Walk Hourglass LR FR Lfoot_fit_Armature_125 | M Neutral Walk Hourglass LR FR Rfoot_fit_Armature_124 | 0.0000 | 0.0317 | 0.0465 | 0.00 |
| M Neutral Walk Hourglass RR BL Lfoot_fit_Armature_119 | M Neutral Walk Hourglass RR BL Rfoot_fit_Armature_118 | 0.0000 | 0.0003 | 0.0001 | 0.00 |
| M Neutral Walk Prism F FR Lfoot_fit_Armature_079 | M Neutral Walk Prism F FR Rfoot_fit_Armature_078 | 0.0000 | 0.0202 | 0.1346 | 0.00 |
| M Neutral Walk Prism FL F Lfoot_fit_Armature_077 | M Neutral Walk Prism FL F Rfoot_fit_Armature_076 | 0.0000 | 0.0486 | 0.0018 | 0.00 |
| M Neutral Walk Prism FR F Lfoot_fit_Armature_075 | M Neutral Walk Prism FR F Rfoot_fit_Armature_074 | 0.0000 | 0.0190 | 0.0015 | 0.00 |
| M Neutral Walk Shuffle LR to LL Lfoot_fit_Armature_061 | M Neutral Walk Shuffle LR to LL Rfoot_fit_Armature_060 | 0.0000 | 0.0000 | 0.0000 | 0.00 |
| M Neutral Walk Stop RL Rfoot_fit_Armature_018 | M Neutral Walk Stop RR Lfoot_fit_Armature_017 | 0.0000 | 0.0252 | 0.0002 | 0.00 |
| M Neutral Transition Walk to Sprint Lfoot_fit_Armature_001 | M Neutral Transition Walk to Sprint Rfoot_fit | 0.0000 | 0.0383 | 0.0219 | 0.00 |
| M Neutral Crouch Box RL B Rfoot_fit_Armature_187 | M Neutral Crouch Box RR B Rfoot_fit_Armature_183 | 0.0000 | 0.0281 | 0.0026 | 0.00 |
| M Neutral Crouch Diamond B FR Lfoot_fit_Armature_178 | M Neutral Crouch Diamond B FR Rfoot_fit_Armature_177 | 0.0000 | 0.0013 | 0.0939 | 0.00 |
| M Neutral Crouch Diamond BR FR Lfoot_fit_Armature_166 | M Neutral Crouch Diamond BR FR Rfoot_fit_Armature_165 | 0.0000 | 0.0001 | 0.0010 | 0.00 |
| M Neutral Crouch Diamond FL FR Lfoot_fit_Armature_156 | M Neutral Crouch Diamond FL FR Rfoot_fit_Armature_155 | 0.0000 | 0.0001 | 0.0009 | 0.00 |
| M Neutral Crouch Hourglass BL RL Lfoot_fit_Armature_148 | M Neutral Crouch Hourglass BL RR Lfoot_fit_Armature_146 | 0.0000 | 0.0011 | 0.0834 | 0.00 |
| M Neutral Crouch Hourglass BL RL Rfoot_fit_Armature_147 | M Neutral Crouch Hourglass BL RR Rfoot_fit_Armature_145 | 0.0000 | 0.0001 | 0.0011 | 0.00 |
| M Neutral Crouch Hourglass FR LR Lfoot_fit_Armature_135 | M Neutral Crouch Hourglass FR LR Rfoot_fit_Armature_134 | 0.0000 | 0.0001 | 0.0003 | 0.00 |
| M Neutral Crouch Hourglass LL BR Lfoot_fit_Armature_133 | M Neutral Crouch Hourglass LR BR Rfoot_fit_Armature_128 | 0.0000 | 0.0002 | 0.0001 | 0.00 |
| M Neutral Crouch Prism FL F Lfoot_fit_Armature_073 | M Neutral Crouch Prism FL F Rfoot_fit_Armature_072 | 0.0000 | 0.0298 | 0.0007 | 0.00 |
| M Neutral Crouch Shuffle LR to LL Lfoot_fit_Armature_061 | M Neutral Crouch Shuffle LR to LL Rfoot_fit_Armature_060 | 0.0000 | 0.0001 | 0.0000 | 0.00 |
| M Neutral Crouch Idle Break v03_fit_Armature_020 | M Neutral Crouch Idle Break v05_fit_Armature_018 | 0.0000 | 0.0142 | 0.0222 | 0.00 |

### Small timing/root-motion-change pairs (first 30)

| A | B | dDuration | PosRMS | SpeedMAE | YawMAE |
|---|---|---:|---:|---:|---:|
| M Neutral Run Box LL B Lfoot_fit_Armature_206 | M Neutral Run Box LR B Lfoot_fit_Armature_202 | 0.0417 | 0.0918 | 0.0362 | 0.00 |
| M Neutral Run Box LR B Lfoot_fit_Armature_202 | M Neutral Run Box LR B Rfoot_fit_Armature_201 | 0.0833 | 0.0992 | 0.0655 | 0.00 |
| M Neutral Run Box LR F Lfoot_fit_Armature_200 | M Neutral Run Box LR F Rfoot_fit_Armature_199 | 0.0417 | 0.0865 | 0.0749 | 0.00 |
| M Neutral Run Diamond B FR Lfoot_fit_Armature_186 | M Neutral Run Diamond B FR Rfoot_fit_Armature_185 | 0.0417 | 0.0639 | 0.0415 | 0.00 |
| M Neutral Run Diamond BR FR Lfoot_fit_Armature_174 | M Neutral Run Diamond BR FR Rfoot_fit_Armature_173 | 0.0417 | 0.0800 | 0.0724 | 0.00 |
| M Neutral Run Diamond FL FR Lfoot_fit_Armature_164 | M Neutral Run Diamond FL FR Rfoot_fit_Armature_163 | 0.0417 | 0.0952 | 0.2575 | 0.00 |
| M Neutral Run Hourglass BL RL Lfoot_fit_Armature_156 | M Neutral Run Hourglass BL RL Rfoot_fit_Armature_155 | 0.0417 | 0.0991 | 0.0435 | 0.00 |
| M Neutral Run Hourglass FL RR Lfoot_fit_Armature_146 | M Neutral Run Hourglass FL RR Rfoot_fit_Armature_145 | 0.0833 | 0.0814 | 0.1153 | 0.00 |
| M Neutral Run Hourglass RL FL Rfoot_fit_Armature_129 | M Neutral Run Hourglass RR FL Rfoot_fit_Armature_125 | 0.0417 | 0.1199 | 0.0829 | 0.00 |
| M Neutral Run Hourglass RR FL Lfoot_fit_Armature_126 | M Neutral Run Hourglass RR FL Rfoot_fit_Armature_125 | 0.0417 | 0.0658 | 0.0632 | 0.00 |
| M Neutral Run Loop RL_fit_Armature_106 | M Neutral Run Loop RR_fit_Armature_105 | 0.0833 | 0.1058 | 0.0666 | 0.00 |
| M Neutral Run Loop RL_fit_Armature_106 | M Neutral Run Shuffle RR to RL Rfoot_fit_Armature_061 | 0.0417 | 0.1195 | 0.1082 | 0.00 |
| M Neutral Run Pivot F B Lfoot_fit_Armature_095 | M Neutral Run Pivot F B Rfoot_fit_Armature_094 | 0.0833 | 0.0785 | 0.1314 | 0.00 |
| M Neutral Run Pivot RL LL Rfoot_fit_Armature_084 | M Neutral Run Pivot RR LR Rfoot_fit_Armature_082 | 0.1667 | 0.0728 | 0.1687 | 0.00 |
| M Neutral Run Prism F FR Lfoot_fit_Armature_078 | M Neutral Run Prism F FR Rfoot_fit_Armature_077 | 0.0417 | 0.0971 | 0.0317 | 0.00 |
| M Neutral Run Start B Lfoot_fit_Armature_059 | M Neutral Run Start B Rfoot_fit_Armature_058 | 0.0833 | 0.0914 | 0.0443 | 0.00 |
| M Neutral Run Start BL Lfoot_fit_Armature_057 | M Neutral Run Start BL Rfoot_fit_Armature_056 | 0.0833 | 0.0929 | 0.0439 | 0.00 |
| M Neutral Run Start LL Rfoot_fit_Armature_046 | M Neutral Run Start LR Lfoot_fit_Armature_045 | 0.0417 | 0.0580 | 0.0343 | 0.00 |
| M Neutral Run Stop BL Lfoot_fit_Armature_037 | M Neutral Run Stop BL Rfoot_fit_Armature_036 | 0.1250 | 0.0090 | 0.0254 | 0.00 |
| M Neutral Run Stop FR Lfoot_fit_Armature_029 | M Neutral Run Stop FR Rfoot_fit_Armature_028 | 0.1250 | 0.1142 | 0.1800 | 0.00 |
| M Neutral Run Stop LL Lfoot_fit_Armature_027 | M Neutral Run Stop LL Rfoot_fit_Armature_026 | 0.0417 | 0.0867 | 0.0412 | 0.00 |
| M Neutral Run Stop LL Lfoot_fit_Armature_027 | M Neutral Run Stop LR Lfoot_fit_Armature_025 | 0.0833 | 0.0009 | 0.0318 | 0.00 |
| M Neutral Run Stop LL Rfoot_fit_Armature_026 | M Neutral Run Stop LR Lfoot_fit_Armature_025 | 0.0417 | 0.0876 | 0.0105 | 0.00 |
| M Neutral Walk Box B LL Lfoot_fit_Armature_213 | M Neutral Walk Box B LL Rfoot_fit_Armature_212 | 0.1250 | 0.0767 | 0.0913 | 0.00 |
| M Neutral Walk Box B LL Rfoot_fit_Armature_212 | M Neutral Walk Box B LR Lfoot_fit_Armature_211 | 0.1250 | 0.0910 | 0.0239 | 0.00 |
| M Neutral Walk Box B RL Lfoot_fit_Armature_209 | M Neutral Walk Box B RR Lfoot_fit_Armature_207 | 0.0417 | 0.0685 | 0.0175 | 0.00 |
| M Neutral Walk Box B RL Lfoot_fit_Armature_209 | M Neutral Walk Box B RR Rfoot_fit_Armature_206 | 0.0417 | 0.0241 | 0.0143 | 0.00 |
| M Neutral Walk Box F LL Lfoot_fit_Armature_205 | M Neutral Walk Box F LR Lfoot_fit_Armature_203 | 0.0417 | 0.0785 | 0.0283 | 0.00 |
| M Neutral Walk Box F LL Lfoot_fit_Armature_205 | M Neutral Walk Box F LR Rfoot_fit_Armature_202 | 0.0417 | 0.1088 | 0.0367 | 0.00 |
| M Neutral Walk Box LL B Lfoot_fit_Armature_197 | M Neutral Walk Box LR B Lfoot_fit_Armature_193 | 0.0417 | 0.0450 | 0.0250 | 0.00 |

## Uncertain classifications

- direction_label=AMBIGUOUS: 53
- direction_label=CURVED/CHANGING: 8
- direction_label=MIXED: 312
- direction_label=NONE: 5
- loop_tag_but_not_clean_root_loop: 48
- low_direction_strength=0.000: 5
- low_direction_strength=0.006: 1
- low_direction_strength=0.007: 2
- low_direction_strength=0.008: 4
- low_direction_strength=0.011: 1
- low_direction_strength=0.012: 2
- low_direction_strength=0.014: 1
- low_direction_strength=0.015: 4
- low_direction_strength=0.016: 1
- low_direction_strength=0.019: 1
- low_direction_strength=0.023: 5
- low_direction_strength=0.025: 1
- low_direction_strength=0.029: 1
- low_direction_strength=0.030: 4
- low_direction_strength=0.036: 1
- low_direction_strength=0.037: 1
- low_direction_strength=0.038: 3
- low_direction_strength=0.041: 1
- low_direction_strength=0.042: 1
- low_direction_strength=0.043: 1
- low_direction_strength=0.045: 2
- low_direction_strength=0.047: 1
- low_direction_strength=0.049: 1
- low_direction_strength=0.050: 1
- low_direction_strength=0.052: 1
- low_direction_strength=0.053: 1
- low_direction_strength=0.056: 1
- low_direction_strength=0.060: 1
- low_direction_strength=0.062: 1
- low_direction_strength=0.076: 1
- low_direction_strength=0.078: 1
- low_direction_strength=0.091: 1
- low_direction_strength=0.095: 1
- low_direction_strength=0.145: 1
- low_direction_strength=0.155: 1
- low_direction_strength=0.163: 1
- low_direction_strength=0.167: 1
- low_direction_strength=0.168: 1
- low_direction_strength=0.211: 2
- low_direction_strength=0.219: 1
- low_direction_strength=0.221: 1
- low_direction_strength=0.228: 2
- low_direction_strength=0.267: 1
- low_direction_strength=0.279: 1
- low_direction_strength=0.292: 1
- low_direction_strength=0.293: 1
- low_direction_strength=0.327: 1
- low_direction_strength=0.333: 2
- low_direction_strength=0.368: 1
- low_direction_strength=0.385: 1
- low_direction_strength=0.388: 1
- low_direction_strength=0.394: 1
- low_direction_strength=0.396: 1
- low_direction_strength=0.408: 1
- low_direction_strength=0.411: 1
- low_direction_strength=0.416: 1
- low_direction_strength=0.417: 2
- low_direction_strength=0.418: 1
- low_direction_strength=0.421: 1
- low_direction_strength=0.423: 1
- low_direction_strength=0.424: 1
- low_direction_strength=0.425: 1
- low_direction_strength=0.426: 1
- low_direction_strength=0.427: 2
- low_direction_strength=0.428: 3
- low_direction_strength=0.429: 4
- low_direction_strength=0.430: 2
- low_direction_strength=0.431: 4
- low_direction_strength=0.432: 2
- low_direction_strength=0.433: 1
- low_direction_strength=0.434: 4
- low_direction_strength=0.435: 4
- low_direction_strength=0.436: 5
- low_direction_strength=0.438: 2
- low_direction_strength=0.439: 2
- low_direction_strength=0.440: 5
- low_direction_strength=0.441: 1
- low_direction_strength=0.442: 1
- low_direction_strength=0.443: 2
- low_direction_strength=0.444: 2
- low_direction_strength=0.445: 1
- measured_category_not_in_apparent:Circle/curved locomotion: 58
- measured_category_not_in_apparent:Pivot: 4
- measured_category_not_in_apparent:Stop: 32
- measured_category_not_in_apparent:Walk: 67
- segment_direction_disagreement: 362
- suitability_conflict:Circle/curved locomotion: 4
- suitability_conflict:Crouch: 6
- suitability_conflict:Idle: 16
- suitability_conflict:Pivot: 60
- suitability_conflict:Run: 23
- suitability_conflict:Sprint: 10
- suitability_conflict:Start: 30
- suitability_conflict:Turn: 58
- suitability_conflict:Walk: 18
- turn_name_without_measured_rotation: 10

| Clip | Measured category | Direction | Reasons |
|---|---|---|---|
| M Neutral Run Box B LL Lfoot_fit_Armature_222 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Box B LL Rfoot_fit_Armature_221 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box B LR Lfoot_fit_Armature_220 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Box B LR Rfoot_fit_Armature_219 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box B RL Lfoot_fit_Armature_218 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box B RL Rfoot_fit_Armature_217 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box B RR Lfoot_fit_Armature_216 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box B RR Rfoot_fit_Armature_215 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Box F LL Lfoot_fit_Armature_214 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box F LL Rfoot_fit_Armature_213 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box F LR Lfoot_fit_Armature_212 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box F LR Rfoot_fit_Armature_211 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box F RL Lfoot_fit_Armature_210 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box F RL Rfoot_fit_Armature_209 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box F RR Lfoot_fit_Armature_208 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box F RR Rfoot_fit_Armature_207 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box LL B Lfoot_fit_Armature_206 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box LL B Rfoot_fit_Armature_205 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Box LL F Lfoot_fit_Armature_204 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box LL F Rfoot_fit_Armature_203 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box LR B Lfoot_fit_Armature_202 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box LR B Rfoot_fit_Armature_201 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Box LR F Lfoot_fit_Armature_200 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box LR F Rfoot_fit_Armature_199 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box RL B Lfoot_fit_Armature_198 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Box RL B Rfoot_fit_Armature_197 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Box RL F Lfoot_fit_Armature_196 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box RL F Rfoot_fit_Armature_195 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box RR B Lfoot_fit_Armature_194 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Box RR B Rfoot_fit_Armature_193 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Box RR F Lfoot_fit_Armature_192 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Circle Strafe L_fit_Armature_190 | Walk | AMBIGUOUS | ["direction_label=AMBIGUOUS", "low_direction_strength=0.045", "suitability_conflict:Run", "suitability_conflict:Circle/curved locomotion", "measured_category_not_in_apparent:Walk", "loop_tag_but_not_clean_root_loop"] |
| M Neutral Run Circle Strafe R_fit_Armature_189 | Walk | AMBIGUOUS | ["direction_label=AMBIGUOUS", "low_direction_strength=0.014", "suitability_conflict:Run", "suitability_conflict:Circle/curved locomotion", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Diamond B FL Lfoot_fit_Armature_188 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Diamond B FL Rfoot_fit_Armature_187 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Diamond B FR Lfoot_fit_Armature_186 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Diamond B FR Rfoot_fit_Armature_185 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |
| M Neutral Run Diamond BL BR Lfoot_fit_Armature_184 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Diamond BL BR Rfoot_fit_Armature_183 | Walk | MIXED | ["direction_label=MIXED", "segment_direction_disagreement", "measured_category_not_in_apparent:Walk"] |
| M Neutral Run Diamond BL F Lfoot_fit_Armature_182 | Run | MIXED | ["direction_label=MIXED", "segment_direction_disagreement"] |

... 528 more in the machine-readable catalog.

## Validation

- Database animations in catalog: 718 / 718
- Database SHA-256 unchanged: true
- Baseline files unchanged: true (3443 files checked)
- Checks passed: 9
- Checks failed: 0
- C++ rebuild performed by diagnostic: false
