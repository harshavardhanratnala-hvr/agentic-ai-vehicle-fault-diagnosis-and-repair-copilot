# Dataset Selection Log — Primary Classifier Training Data

This log documents every candidate dataset evaluated for the primary Battery/EV fault classifier
(Week 1), why each was accepted or rejected, and the actual tests run — not just a description of
columns. Referenced from `Capstone_Project_Plan.md` Section 2 so the reasoning behind the final
choice is traceable, not just the outcome.

## Why this was needed

The dataset originally locked into the plan — *EV Battery and Drivetrain Fault Diagnosis*
(`programmer3/ev-battery-and-drivetrain-fault-diagnosis`, ~237K rows) — had been removed from
Kaggle by the time Week 1 data-pulling started. The Kaggle page 404s, it doesn't appear in search,
and the uploader's account no longer lists it among their datasets. A replacement had to be found
and verified before any classifier work could start.

## The core lesson: column names are not enough — signal has to be tested

The first replacement pass (below) picked a dataset that looked like a strong structural match —
right scale, plausible sensor columns, a `Failure_Probability` target — purely from inspecting
columns, ranges, and class balance. It was locked into the plan. It turned out to be unusable: a
Random Forest trained on all 24 sensor columns to predict `Failure_Probability` scored **AUC =
0.4975** — statistically identical to a coin flip. Every sensor's mean value differed by under 2%
between the failure and non-failure groups. The label had been generated independently of the
features, with no causal relationship for any model to learn.

From that point on, every subsequent candidate was stress-tested the same way before being
considered: **fit a quick classifier on the candidate's own features against its own target and
check AUC/accuracy against the naive baseline (majority class / coin flip).** A dataset only
qualifies if it clears that bar by a wide margin.

## Candidates evaluated

### 1. `programmer3/ev-battery-and-drivetrain-fault-diagnosis` — originally planned
- **Status:** Gone. 404 on the dataset page; not in Kaggle search; not among the uploader's
  current datasets (which are now on unrelated topics).
- **Outcome:** Could not be used — this is what triggered the search below.

### 2. `datasetengineer/eviot-predictivemaint-dataset` — EVIoT-PredictiveMaint Dataset
- **Why it looked good:** 175,393 rows, 30 columns, real 15-minute-interval time series —
  battery voltage/current/temperature/SoC/SoH, motor temperature/vibration/torque/RPM, plus
  brake/tire/suspension telemetry. `Failure_Probability` (binary, ~9.9% positive) and
  `Maintenance_Type` (4 severities) as candidate targets. Scale close to the original plan
  (175K vs. 237K), realistic-looking imbalance. **This was briefly locked into the plan.**
- **Why it was rejected (after deeper testing):**
  - No nulls, no duplicates, all sensor ranges physically plausible — passed every surface-level
    check.
  - But `Component_Health_Score`, `RUL`, `TTF` had **near-identical distributions** regardless of
    `Failure_Probability` (same mean/std either way) — no relationship.
  - Random Forest on all 24 sensor columns → `Failure_Probability`: **AUC 0.4975** (chance level).
  - Random Forest on all 24 sensor columns → `Maintenance_Type` (4-class): accuracy 70.0%, which
    is exactly the majority-class prior (70.1%) — the model learned nothing beyond "always guess
    the biggest class."
  - Every sensor's mean value differed by under 2% between failure and non-failure rows.
  - **Conclusion:** the target columns appear to have been generated independently of the sensor
    features. Not usable for a classifier that needs to demonstrate real learned signal.
- **Disposition:** raw file deleted from `data/raw/` once rejected.

### 3. `ziya07/fault-diagnosis-dataset-for-new-energy-vehicles` — NEV Fault Diagnosis
- **First-pass read:** 11,000 rows, 8 columns (Voltage, Current, Motor Speed, Temperature,
  Vibration, Ambient Temp, Humidity, Fault Label). Values pre-scaled to 0-1, and `Fault Label`
  class counts were suspiciously round (5000/2000/2000/2000 across 4 classes) — **rejected on
  first pass** as looking synthetic/generated rather than measured.
- **Re-tested after the EVIoT failure** (in case "looks synthetic" had wrongly been treated as
  disqualifying): Random Forest on the 7 sensor columns → `Fault Label`: **accuracy 99.4%, macro
  F1 0.99**. The labels genuinely are derived from the features — this one has real signal, just
  via an obvious rule/generator rather than measurement noise.
- **Why still not selected:** small (11K rows), class balance is 45%/18%/18%/18% — not the
  rare-fault imbalance the project wants to demonstrate handling for — and the pre-scaled 0-1
  values make it look and feel the least authentic of the finalists.
- **Disposition:** not pulled into `data/raw/`; evaluated from a temp download only.

### 4. `bertnardomariouskono/electric-vehicle-ev-battery-degradation-and-charge`
- **What it is:** 10,000 rows, per-vehicle aggregate snapshot (battery age, charge cycles, SoH,
  driving style) rather than a per-reading sensor stream.
- **Why rejected:** target `Battery_Status` is 9,996 `Healthy` vs. **4** `Replace Required` —
  an unusably extreme split for a 3-class Normal/Warning/Fault framing, and structurally this is a
  battery-aging/SoH dataset, not a fault-classification dataset.
- **Disposition:** not pulled into `data/raw/`; evaluated from a temp download only.

### 5. `micamadi/synthetic-distributed-battery-management-system`
- **What it is:** 600 rows, per-module BMS telemetry (cell voltage/temp, SoC/SoH, an
  `anomaly_score_pct` and `diagnostic_flag`).
- **Why rejected:** too small for a training set at this project's scale — noted as a possible
  small supplementary/demo dataset, not evaluated further.

### 6. `darshangovindaraju/5-year-ev-battery-dataset-for-soh-soc-and-faults`
- **What it is:** 3,000,000 rows, 50 columns, single-cell battery simulation across charge
  cycles — 5 manufacturers × 3 chemistries (NMC/LFP/NCA). Seven boolean fault flags: overcurrent,
  undercurrent, over-voltage, under-voltage, over-temperature, under-temperature, short-circuit.
- **Signal test:** Random Forest on 18 raw sensor columns (explicitly excluding the built-in
  `*_limit_*` threshold columns, to test whether the flag is learnable from natural sensor
  readings and not just a lookup against a threshold in the same row) → predicting "any fault":
  **AUC 0.9985, F1 0.998**, driven sensibly by `heat_generation_W`/`current_A`/`c_rate` — genuine,
  physically coherent signal.
- **Why not selected despite passing the signal test:**
  - **4 of the 7 fault-flag columns are dead** — `over_voltage_flag`, `under_voltage_flag`,
    `over_temperature_flag`, and `under_temperature_flag` are `0` across all 3,000,000 rows,
    verified by a full-file scan, not a sample. Only overcurrent (0.81%), undercurrent (0.82%),
    and short-circuit (0.005%, only 157 rows total) ever fire.
  - License is CC BY-SA 4.0 (share-alike) — more restrictive than the alternative.
  - Single-cell-in-a-lab framing doesn't map as cleanly onto the "a truck in the fleet just threw
    a fault code" persona narrative the project is built around.
  - 3,000,000 rows is far more than a 4-week bootcamp classifier needs; would require deliberate
    subsampling.
- **Disposition:** kept as a documented fallback, not pulled into `data/raw/`.

### 7. `kunalm95/ev-sensors-driving-pattern-diagnostics-2020-24` — **selected**
- **What it is:** 175,200 rows — 4 EVs (rare/moderate/heavy/daily usage profiles) × 5 years,
  hourly telemetry. SOC, SOH, charging cycles, battery temp, motor RPM/torque/temp, brake pad
  wear, charging voltage, tire pressure, and a `DTC` (Diagnostic Trouble Code) column with real,
  named codes: `P0MR` (motor RPM), `P0MT` (motor temp), `P0T` (general temp), `P0P` (pressure),
  `P0B` (battery), `P0S` (SOC/SOH) — including rows with multiple simultaneous codes.
- **Signal test:** Random Forest on the 10 sensor columns → has-any-DTC: **AUC 0.9999, F1 0.995**,
  dominated by `Motor_RPM`/`Motor_Torque`/`Motor_Temp` — consistent with the `P0MR`/`P0MT` code
  names, i.e. the relationship is not just statistically real but semantically sensible.
- **Fault rate:** 1.63% of rows carry any DTC — realistic, rare-event imbalance.
- **License:** CC BY 4.0 (attribution only, commercial use allowed).
- **Why this one:** clears the signal bar by the same margin as the 3M-row alternative, at a
  much more practical scale, with a cleaner license, and — unlike every other candidate — its
  target is literally a diagnostic trouble code on a vehicle, which is the exact mechanism
  described in the plan's own Section 1 concept ("a diagnostic trouble code... works the problem
  the way a diagnostic engineer would").
- **Disposition:** pulled into `data/raw/driving_pattern_diagnostics/` (4 CSVs + the dataset's own
  README/LICENSE). This is the dataset the plan now points to.

## Summary table

| Candidate | Rows | Signal test result | Verdict |
|---|---|---|---|
| `programmer3/...` (original) | ~237K | N/A — dataset no longer exists | Unavailable |
| `datasetengineer/eviot-predictivemaint-dataset` | 175,393 | AUC 0.4975 (chance) | Rejected — no signal |
| `ziya07/fault-diagnosis-dataset-for-new-energy-vehicles` | 11,000 | Accuracy 99.4%, F1 0.99 | Rejected — too small, unrealistic balance |
| `bertnardomariouskono/...battery-degradation-and-charge` | 10,000 | Not tested — target unusable (9996 vs. 4) | Rejected — wrong problem shape |
| `micamadi/synthetic-distributed-battery-management-system` | 600 | Not tested — too small | Rejected — insufficient scale |
| `darshangovindaraju/5-year-ev-battery-dataset-for-soh-soc-and-faults` | 3,000,000 | AUC 0.9985, F1 0.998 | Passed, but 4/7 target columns dead + oversized + more restrictive license |
| `kunalm95/ev-sensors-driving-pattern-diagnostics-2020-24` | 175,200 | AUC 0.9999, F1 0.995 | **Selected** |
