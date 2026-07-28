# Data → Baseline Classifier Pipeline

End-to-end flow across `notebooks/01_eda.ipynb` and `notebooks/02_baseline_classifier.ipynb`.

## Notebook 1 — EDA (`01_eda.ipynb`)

**1. Load raw data**
4 CSVs (rare/moderate/heavy/daily user) concatenated → 175,200 rows, tagged with `user_profile`.

**2. Data quality checks**
Duplicates, nulls, dtypes, physically-plausible sensor ranges (e.g. SOC 0–100%, battery temp -20 to 80°C) — all pass.

**3. Derive `Fault_Label` from `DTC`**
Rule applied to the raw diagnostic trouble code column:
- Motor/battery codes (`P0MR`, `P0MT`, `P0B`) or multiple simultaneous codes → **Fault**
- Single advisory code (`P0T`, `P0P`, `P0S`) → **Warning**
- No code (`DTC == "0"`) → **Normal**

**4. Class balance + realism checks**
Normal 98.37% / Fault 1.51% / Warning 0.12%. Fault rate scales with usage intensity (0.99% rare_user → 2.57% heavy_user). Key sensors (Motor_RPM, Motor_Torque, Motor_Temp) visibly separate by class.

**5. Temporal leakage check**
95.7% of fault episodes are single isolated hours (not multi-hour runs); fault rate is flat across the 5 years.
→ **Decision: chronological, per-vehicle train/test split** (last ~20% of each vehicle's own timeline as test) — not a random row split.

**6. Save cleaned dataset**
`data/processed/driving_pattern_diagnostics_cleaned.csv` — ready for Week 2.

---

## Notebook 2 — Baseline Classifier (`02_baseline_classifier.ipynb`)

**7. Load cleaned data + apply the split**
Per vehicle: last ~20% of its own timeline → test.
Train: 140,160 rows (2020-01-01 to 2023-12-30). Test: 35,040 rows (2023-12-31 to 2024-12-29).

**8. Feature relevance (train fold only)**
`mutual_info_classif` vs. `Fault_Label` → Motor_RPM / Motor_Torque dominate; SOH / Charging_Cycles ≈ 0 information. Confirms no threshold/derived columns snuck into the feature set.

**9. Train Random Forest + XGBoost**
Class weights (`class_weight="balanced"` / `compute_sample_weight`) computed from the training fold only. No resampling (no SMOTE) and no lag/rolling features were used.

**10. Evaluate on unseen 2024 data**
Macro F1, per-class recall, confusion matrix, plus a binary Normal-vs-Any-Issue rollup — deliberately not plain accuracy, which would be meaningless at 98.37% Normal.

**11. Sanity-check the perfect RF score**
Random Forest = 1.000 macro F1 (including all 42 Warning rows in test); XGBoost = 0.985 (not perfect). The gap between the two models is the cross-check: if this were a leak, both should trivially hit 100%, not just one. Read as a rule-based synthetic label the model recovers, not a data leak — but this needs re-testing against real-world data before trusting it beyond this dataset.

**12. Save models**
`models/baseline_random_forest.joblib`, `models/baseline_xgboost.joblib` — feeds the Week 3 agent's `classify_fault()` tool. (`models/` is gitignored; each teammate regenerates by rerunning the notebook.)

---

## Caveat that carries through the instant-classification pipeline

These results describe how well a model fits **this simulated dataset's labeling rule** — not a claim about performance on real, noisy fleet telemetry. Keep that distinction explicit in any write-up or presentation, not glossed over as "the model is 100% accurate."

---

## Reframing: instant classification → forecasting (coach feedback, 2026-07-28)

Our coach correctly flagged that steps 7-11 above treat each hourly row as an **independent classification sample**, when this is actually 4 continuous per-vehicle time series — and the dataset's own README states its intended use cases as "multivariate time-series forecasting" and "DTC forecasting and anomaly detection," not row-level classification. The instant-classification notebooks above are kept as-is (valid, documented work, not deleted) — this adds a second, parallel pipeline on top of the same data and the same `Fault_Label` logic.

### Notebook 1b — Sequence Features (`01b_sequence_features.ipynb`)

**12. Rolling/lag/delta features, per vehicle, no look-ahead**
40 features across `Motor_RPM`, `Motor_Torque`, `Motor_Temp`, `Battery_Temp`: rolling mean/std (6h/12h/24h trailing windows), lags (1h/3h/6h), and a 6h delta. All computed via `groupby("user_profile")` — verified with an explicit no-cross-vehicle-bleed check.

**13. Forward-looking target: `Fault_Within_6h` / `Fault_Within_12h`**
True if any of the next N hours (same vehicle, strictly after the current row) has `Fault_Label != "Normal"`. The helper function was cross-checked against a brute-force loop on a hand-built example before trusting it on 175K rows. Class balance: **9.05% positive at 6h, 17.15% at 12h** — both far less extreme than the 1.63% instant-level rate, as expected.

**14. Drop incomplete-window rows**
92 cold-start rows (23/vehicle, first 24h) dropped globally; each target's own end-of-timeline NaNs (24 rows for 6h, 48 for 12h) are left for the training notebook to drop per-target.

**15. Feature relevance vs. the new target**
Rolling-window features dominate, as expected. But `Brake_Pad_Wear` and `SOH` also jumped from near-zero to top-7 relevance — flagged as a possible vehicle-identity confound (both track usage intensity, which also drives fault rate) for the next notebook to test, not assumed.

### Notebook 3 — Sequence Classifier (`03_sequence_classifier.ipynb`)

**16. Retrain on `Fault_Within_6h`**
Same `Pipeline(StandardScaler → classifier)` shape, same chronological per-vehicle split, same train-fold-only class weighting as notebook 2 — only the target and feature set changed.

**17. Results dropped substantially — the correct outcome, not a regression**
Macro F1 ~1.000/0.985 (instant) → **~0.60/0.59** (forecast); positive-class recall ~99% → **~46-59%**; precision ~23%. Moving from "recognize a code that's already set" (near-tautological) to "forecast a code before it exists" (genuinely hard) is exactly why the score should drop.

**18. The `01b` confound hypothesis was tested and found wrong**
Per-vehicle mutual information for `Brake_Pad_Wear`/`SOH` is *higher* than pooled, not lower — a real within-vehicle relationship exists, not a cross-vehicle artifact. The trained model just doesn't lean on those two specifically (likely redundant with `Charging_Cycles`/rolling motor stats). Reported as "hypothesis tested and revised," not forced to match the original guess.

**19. Save models**
`models/sequence_random_forest.joblib`, `models/sequence_xgboost.joblib` — alongside, not replacing, `baseline_*.joblib`.

### Caveat for this pipeline

~0.60 macro F1 is a real, honest baseline for a genuinely hard forecasting problem — not a finished result. Next candidates: the 12h window (more positive examples), a small neural net on the same features, and following up on why `Tire_Pressure`/`Charging_Voltage` (not `Brake_Pad_Wear`/`SOH`) top the trained model's own permutation importance.
