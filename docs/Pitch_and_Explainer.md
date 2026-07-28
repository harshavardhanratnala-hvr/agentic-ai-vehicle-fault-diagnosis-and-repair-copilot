# Agentic AI Vehicle Fault Diagnosis & Repair Copilot — Pitch & Explainer

## The problem

Vehicle problems show up in two ways, and both are handled badly today. Sometimes a fault code fires and a human has to interpret it by hand, cross-referencing manufacturer bulletins and recall databases. And sometimes the warning signs are there in the sensor trend well before any code fires, but nobody is watching closely enough to catch it early. Both are slow, manual, and inconsistent.

## What we're building

An AI "copilot" that handles both sides. It watches a vehicle's telemetry continuously to catch trouble before it becomes a breakdown — and, once a fault is known (whether forecast early or already fired as a DTC), it:

1. Classifies what kind of fault it likely is and how serious.
2. Looks up real government safety records (NHTSA recalls, complaints, technical bulletins) about that specific issue.
3. Writes up a clear repair recommendation that cites those real records instead of making things up.

You watch it think through each step, not just spit out an answer.

## One-sentence pitch for a general audience

> "We built an AI copilot that watches a vehicle's telemetry to catch trouble before it becomes a breakdown, and, once a fault is known, automatically figures out what's wrong, pulls up real recall and repair records for that exact problem, and writes a diagnosis you can trust because it shows its sources."

## Who this is for — and why

Three questions that come up every time this gets pitched, so worth answering before they're asked:

- **Who exactly is it for?** Fleet maintenance manager, primary — the question they ask is literally "pull it in now, or keep driving?" OEM/dealer diagnostic engineer, secondary — same agent output (classification + citations + root cause), different question ("what's the root cause, has it been seen before, what's the fix?").
- **Pre-production or post-production?** Post-production, in-service. This diagnoses vehicles already built and on the road that just threw a live fault code — it is not a manufacturing-line quality-control tool.
- **Why not a customer/driver-facing app?** Not ruled out — cut for scope. A driver-facing safety recommendation needs a much higher trust/liability bar than a professional-user tool (a "Warning" misread by a driver as "ignore it" is a real risk). Building two audiences well in 4 weeks means either double the UI work or one shallow build that serves neither. The same underlying agent output generalizes to a consumer app later — that's an explicit future extension, not a limitation of the approach.

### These two roles, explained without assuming any automotive background

**Fleet maintenance manager.** Picture a company that owns a bunch of delivery vans or trucks (think Amazon's delivery fleet, or a trucking company). This person's job is to keep all those vehicles running and on schedule. When one throws a warning, their question is purely practical: *"Is this vehicle safe to keep driving today, or do I pull it off the road right now?"* They're not fixing anything themselves — they're making a business/safety call about whether to keep a vehicle running or bench it.

**Dealer diagnostic engineer.** This is someone who works at a dealership or repair shop, and their job is to actually find and fix the problem once a vehicle is already in for service. Their question is different: *"What's causing this code? Has this exact issue shown up before? Is there a known recall or repair bulletin for it? What are the repair steps?"* They're the person with hands in the engine bay (or a laptop plugged into the car's computer) doing the technical diagnosis and repair.

**The difference in one line:** the fleet manager asks a go/no-go triage question *before* the vehicle is even in a shop; the dealer engineer asks a root-cause repair question *once* it's already there. Same underlying AI output (classify the fault, pull up relevant records, explain what's going on) — just a different question depending on who's asking.

## How it works (the architecture)

Walking through it left to right, top to bottom — this is the script for the "How It Works" slide:

1. **Two entry points, one agent:**
   - **Continuous telemetry** (fleet manager side) — the forecasting classifier watches the vehicle's ongoing sensor trend and flags trouble before it happens.
   - **Sensor / DTC trigger** (service center side) — a fault has already fired; the vehicle is already at, or heading to, a shop.

   Both feed the same Agent Orchestrator. Forecasting isn't a separate pipeline bolted on the side — it's just an earlier possible starting point into the identical classify → retrieve → generate loop.
2. **Agent Orchestrator (LLM)** — the agent receives whichever input arrived and decides, step by step, which of its tools to call and in what order. This is the "agentic" part — nothing here is a fixed, hardcoded sequence.
3. **Three tools it can call:**
   - **Classify Fault** — forecasts whether a fault is likely within the next few hours from continuous telemetry, or classifies severity once a DTC has already fired (see "Reframing the classifier" below for why the forecasting side is forward-looking, not an instant readout).
   - **Search Recalls & TSBs** — RAG retrieval over the NHTSA corpus, pulling real recall/complaint records relevant to that specific fault.
   - **Generate Ticket** — the LLM writes a structured, cited repair recommendation from whatever the first two tools returned.
4. **Dashboard** — shows both the agent's step-by-step reasoning trace and the final ticket, not just an end answer.

The point to land when explaining this: a "basic" version would just be one classifier spitting out a label after a code has already fired. Here, the LLM is making a decision at each step about what to do next — and the system can start even earlier than that, from telemetry trend alone, before any code exists — which is what makes it agentic rather than a fixed, purely reactive pipeline.

## Data rigor: every dataset earns its spot

Worth telling this part of the story out loud — it's a better signal of how the project was actually run than any polished slide.

The originally planned classifier training dataset was removed from Kaggle during our prep, ahead of kickoff (page gone, not in search, not among the uploader's current datasets). Rather than grabbing the next lookalike dataset, every candidate that followed was put through the same test: fit a quick model on the candidate's own features against its own labels, and check the AUC against a coin-flip baseline. A dataset only qualifies if it clears that bar by a wide margin.

That test caught a real problem. One candidate looked ideal on paper — right scale, plausible sensor columns, a realistic-looking imbalance — and was briefly locked into the plan. Signal-tested anyway, it turned out to have **no real signal — same as guessing** (AUC 0.4975, statistically identical to a coin flip); every sensor's mean value differed by under 2% between the fault and non-fault groups. The label had clearly been generated independently of the features.

The dataset that replaced it (`kunalm95/ev-sensors-driving-pattern-diagnostics-2020-24`) cleared the bar decisively — it **learns the real pattern** (AUC 0.9999, F1 0.995) — and unlike the rejected candidate, the feature importances make physical sense: `Motor_RPM`/`Motor_Torque`/`Motor_Temp` drive the prediction, which lines up with the dataset's own real DTC code names (`P0MR` = motor RPM, `P0MT` = motor temp). Full trial history for every candidate evaluated, including the ones that failed, is in `docs/Dataset_Selection_Log.md`.

## Reframing the classifier: from instant classification to forecasting

Our coach reviewed the Week 1/2 results and made a correct catch: `01_eda.ipynb` and `02_baseline_classifier.ipynb` treated each of the 175,200 hourly rows as an independent sample — "given this one instant's sensor readings, what's its label?" But this dataset is not 175,200 independent rows. It's **4 continuous 5-year per-vehicle time series**, sampled hourly, and row-level classification quietly assumes each hour is unrelated to the one before or after it — false by construction here.

This wasn't just his opinion to argue with — it's the dataset's own stated purpose. Its Kaggle README lists its intended use cases as "multivariate time-series forecasting," "predictive maintenance modeling," and "DTC forecasting and anomaly detection" — not row-level classification. Its own Overview goes further: the dataset was built to "detect early warning signs of system faults, and forecast upcoming Diagnostic Trouble Codes (DTCs) using sensor-based historical data." We also checked the dataset's Kaggle Code/Discussion tabs directly (both show 0) — no prior public notebook exists to lean on, so this reframing was worked out from first principles rather than copied from someone else's approach.

It also matches the actual product question better: the fleet manager's real question — "is it safe to keep driving, or do I pull it in now?" — is inherently forward-looking. A model that only recognizes a fault after the dashboard light is already on isn't triage, it's just reading a light that's already lit.

**What changed, concretely:**
- New rolling/lag/delta features per vehicle (6h/12h/24h rolling mean & std, 1h/3h/6h lags, 6h delta) on `Motor_RPM`, `Motor_Torque`, `Motor_Temp`, `Battery_Temp` — computed strictly within each vehicle's own timeline, verified with an explicit no-cross-vehicle-bleed check.
- A new target, `Fault_Within_6h` (and `Fault_Within_12h`) — "will a fault occur in the next N hours?" instead of "is a fault happening right now?" — hand-verified against a brute-force reference implementation before trusting it on the full dataset.
- Everything else stayed the same: same dataset, same `Fault_Label` derivation logic, same fleet-manager persona, same chronological per-vehicle split methodology.

**The result — and why a worse-looking number is the right outcome:**

| Task | Model | Macro F1 | Positive-class recall |
|---|---|---|---|
| Instant `Fault_Label` (Week 2 baseline) | Random Forest | 1.000 | 0.998 |
| Instant `Fault_Label` (Week 2 baseline) | XGBoost | 0.985 | 0.987 |
| Forecast `Fault_Within_6h` (reframed) | Random Forest | 0.599 | 0.594 |
| Forecast `Fault_Within_6h` (reframed) | XGBoost | 0.594 | 0.468 |

Macro F1 dropped from ~1.000/0.985 to ~0.60/0.59, and recall on catching an upcoming fault dropped to ~46–59%. That's the correct outcome, not a regression: the old score wasn't measuring a hard problem — it was measuring how easy it is to recognize a code using the same instant's readings that generated it. This new number is a genuine, unsolved-feeling forecasting baseline, and a far more defensible one to bring to a coach.

One extra layer of rigor worth mentioning: a hypothesis was raised that two features (`Brake_Pad_Wear`, `SOH`) looked newly important only because they act as a proxy for "which vehicle is this" (a confound), not real signal. Testing it with permutation importance and per-vehicle mutual information showed the opposite — per-vehicle relevance was *higher* than the pooled value, meaning it's genuine within-vehicle signal, not a confound. Worth stating plainly: the hypothesis was tested and found wrong, not quietly adjusted to fit.

## Data & evaluation — FAQ for the coach conversation

**If the classifier now forecasts ahead, how does that reconcile with the service center being the business goal?** They operate at two different moments, and it's worth being explicit about the difference. The forecasting classifier (`Fault_Within_6h`) sits upstream, on the fleet manager's side, watching continuous telemetry before a vehicle ever reaches a shop — its job is to catch a fault early enough that the vehicle can be scheduled in proactively, avoiding unplanned downtime. The service center persona (the dealer/OEM diagnostic engineer) operates downstream of that: by the time a vehicle is physically at the shop, a fault has already occurred, so their question is root cause and repair, not forecasting. That downstream workflow is served by the RAG retrieval and ticket-generation tools, not the classifier, so it's unaffected by the forecasting reframe either way. In short: the classifier decides *when* a vehicle should get to the service center; the agent's other two tools handle what happens *once* it's there.

**What's the realistic product here — does a user really type in 10 sensor values?** No. The classifier's input comes automatically from the vehicle's existing telemetry/telematics feed — this is how real connected fleets already work, no manual entry involved. The only thing a person ever sees is a fault alert plus the agent's diagnosis and reasoning trace on a dashboard, never a 10-field data-entry form. Since a live telemetry integration is out of scope for 4 weeks, the demo simulates this by replaying real held-out rows through the pipeline as if they arrived live — a documented scope decision, not an oversight.

**What are the most important measurable features, and which model uses them?** One model — the fault classifier — takes the 10 sensor columns (`SOC`, `SOH`, `Charging_Cycles`, `Battery_Temp`, `Motor_RPM`, `Motor_Torque`, `Motor_Temp`, `Brake_Pad_Wear`, `Charging_Voltage`, `Tire_Pressure`) as input and predicts `Fault_Label`. Not all 10 are equally important: the dataset-selection signal test already showed `Motor_RPM`/`Motor_Torque`/`Motor_Temp` driving the AUC 0.9999 result, consistent with the Fault-tier DTCs being motor/battery codes. `Brake_Pad_Wear`, `Charging_Voltage`, and `Tire_Pressure` are expected to matter less for this Battery/EV-locked target — `Tire_Pressure` in particular maps to a Warning-tier code, not Fault. Week 2 will confirm this formally with `sklearn.feature_selection.mutual_info_classif`, a second, non-linear-aware ranking alongside the Random Forest importances already observed, rather than assuming all 10 columns pull equal weight.

**Are any of the columns causing leakage — i.e., quietly forcing a good result?** Checked, and no — none of the 10 sensor columns are threshold/limit columns or otherwise mechanically derived from the `DTC` column itself. This is the same discipline that got an earlier candidate dataset rejected (`docs/Dataset_Selection_Log.md`): that one had `*_limit_*` columns which were explicitly excluded from its signal test for exactly this reason, since a column that directly encodes the label-setting logic would trivially "predict" the label without learning anything real. Worth stating this as an explicit, confirmed check on the final dataset, not just something inferred from the earlier candidate-rejection process.

**Do we train on all 175,200 rows, or just the Warning/Fault rows?** All of it. The classifier needs plenty of "Normal" examples to learn what normal looks like — training only on the rare classes would give it nothing to contrast against. The severe imbalance (Normal 98.37% / Fault 1.51% / Warning 0.12%) isn't solved by dropping rows; it's solved with class weighting and possibly oversampling the minority classes in Week 2, both of which need the full dataset present.

**What does NHTSA stand for, and what are the 202 recalls + 3,329 complaints?** NHTSA = National Highway Traffic Safety Administration, the U.S. government agency that regulates vehicle safety. A *recall* is a manufacturer admitting a defect and calling cars in for a free fix; a *complaint* is an owner reporting an issue themselves. The 202 recalls + 3,329 complaints are real public records pulled from NHTSA's API, filtered down to battery/electrical component tags across ~15–20 EV models.

**Are the NHTSA records part of the classifier's train/test split?** No — this is an easy thing to conflate, so worth stating explicitly. Train/test splits apply to the *classifier*, which only ever sees sensor data. The NHTSA recalls/complaints are a completely separate pile of text used for **retrieval (RAG)** — the agent's second tool searches this corpus to find real records relevant to a fault, so its recommendation cites something real instead of inventing a repair. There's no "training" on this text at all; it's a searchable knowledge base, not a supervised-learning dataset.

**What does DTC mean, and what are the actual codes?** Diagnostic Trouble Code — the specific error code a car's onboard computer sets when it detects a problem (this is what triggers a check-engine-style warning). This dataset has 6: `P0MR` (motor RPM anomaly), `P0MT` (motor temperature anomaly), `P0T` (general temperature anomaly), `P0P` (tire pressure anomaly), `P0B` (battery anomaly), `P0S` (state-of-charge/state-of-health anomaly).

**What evaluation metrics will we report, and why not plain accuracy?** Plain accuracy is meaningless here — with 98.37% of rows labeled Normal, a model that always guesses "Normal" scores 98%+ while learning nothing. Instead:

- **Macro F1 + per-class recall + confusion matrix** across the 3 classes (Normal/Warning/Fault) — macro F1 averages each class's F1 equally, so the huge Normal class can't dominate the score the way it dominates accuracy. Recall specifically answers "of all the real faults, how many did we actually catch?" — critical here because a missed fault (telling someone "keep driving" when it's unsafe) is worse than a false alarm.
- **A binary Normal-vs-Any-Issue rollup** as the statistically reliable headline number — Warning has only ~40 rows in the test split, so its own precision/recall are reported as directional, not a confident estimate, while the binary rollup has enough samples behind it to state with real confidence.
- **A chronological, per-vehicle split** (last ~20% of each vehicle's timeline held out), not a random row split — adjacent hours of sensor data are correlated with each other, and a random split would let the model "peek" at near-identical neighboring hours between train and test.

**Why does AUC show up already — isn't that supposed to happen during the ML process, not before it?** It is part of the ML process — just an earlier, different step than the final model evaluation. The AUC numbers (0.4975 vs. 0.9999) came from a quick **data-validation sanity check during dataset selection**: "does this candidate dataset even have a real relationship between its sensors and its labels, before committing a week to training on it?" That's separate from the actual classifier evaluation (macro F1, confusion matrix, per-class recall) described above, which happens once training starts, on the real train/test split. Worth stating this distinction out loud — it's an easy thing for anyone listening to conflate.

**Isn't a perfect 1.000 score suspicious — is this actually classification, or is it a time-series problem?** Yes to the suspicion, and our coach caught this directly: with 4 vehicles logged hourly over 5 years, this is 4 continuous time series, not 175,200 independent samples, and the dataset's own README says its intended use is forecasting, not row-level classification. We reframed the task from "classify this instant" to "forecast a fault in the next 6 hours" using rolling/lag features per vehicle — see "Reframing the classifier" above. The score dropped to a real, honest ~0.60 macro F1 once the task stopped being near-tautological, which is the evidence that the original 1.000 was measuring an easy label, not a leak or a mistake.

## Why "agentic" matters here (the novel part)

A basic version would be one model doing one thing. This instead has an AI that decides which tools to call and in what order — like a junior engineer who knows to check the sensor reading, then look up the bulletins, then write the ticket — rather than a fixed script. That's the "agentic AI" skill that's in demand right now, on top of the more standard "train a classifier" and "do RAG" pieces.

## Prior art — does this already exist?

Yes, and that's a good thing to say out loud in the pitch: it means the problem is real and validated, not a toy.

- **MECH AI** — a consumer app that cross-references OBD-II codes against NHTSA recall data.
- **Recall Recon** (99P Labs) — a published ML + RAG system for forecasting automotive safety recalls from NHTSA data.
- **Academic precedent** — a 2025 Springer paper ("Automated vehicle fault diagnosis and report generation using hybrid machine learning with multi-step RAG") describes almost the same architecture: classifier + RAG over manuals/fault codes → generated diagnostic report.

So the individual pieces (classifier, RAG over NHTSA/manuals, diagnostic report generation) all have precedent in research and industry.

## How this project differs / the pitch angle

Don't claim "nobody's done this." Claim: most existing tools are either a single-shot pipeline (classify → template output, no real decision-making) or a closed commercial product with no visible reasoning. This project's differentiators:

- **Agentic orchestration** — an LLM decides which tool to call next (classify, retrieve, generate) rather than following a fixed script, and that reasoning trace is visible in the UI, not hidden.
- **Full stack, hands-on** — fine-tuning, RAG, agent orchestration, deployment, and monitoring, all built and owned end-to-end rather than stitched from a vendor API.
- **Grounded, cited output** — the agent can't invent remedies; every recommendation traces back to a real NHTSA record, and empty-retrieval cases are handled explicitly rather than papered over.

## The scope, concretely, in 4 weeks

- One vehicle subsystem only — **Battery/EV, locked** (not "all car problems," that's too broad).
- A small trained classifier, trained on a real DTC-based dataset (175,200 rows, 4 EVs × 5 years hourly). Reframed from instant classification to forecasting (`Fault_Within_6h`) per coach feedback — real macro F1 ~0.60 on a genuine forecasting task, not the misleadingly perfect 1.000 from the original instant-classification framing.
- A search system over NHTSA's public repair records — 202 recalls + 3,329 complaints filtered to battery/electrical component tags.
- An AI agent that chains those two together and writes the final report.
- A simple web dashboard to demo it.

## Sources

- [Automated vehicle fault diagnosis and report generation using hybrid machine learning with multi-step RAG approach](https://link.springer.com/article/10.1007/s10791-025-09823-8)
- [Vehicle Recalls & Common Problems Database — NHTSA Data | MECH AI](https://mechai.app/diagnose/recalls/)
- [Recall Recon: A Machine Learning and RAG-Based System for Forecasting Automotive Safety Recalls](https://medium.com/99p-labs/recall-recon-a-machine-learning-and-rag-based-system-for-forecasting-automotive-safety-recalls-29f5d858385f)
