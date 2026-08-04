# Capstone Project Plan: Agentic AI Vehicle Fault Diagnosis & Repair Copilot

**Team:** Harsha, Ghada, Hüseyin
**Program:** neue fische Data Science & AI Bootcamp
**Duration:** 4 weeks

## 1. Concept

An agentic AI system with two entry points feeding the same agent: **continuous vehicle telemetry**, which the classifier watches to forecast a fault before it happens (fleet-manager side), and a **diagnostic trouble code trigger**, when a fault has already fired and needs explaining (service-center side). Either way, the same Agent Orchestrator works the problem autonomously the way a diagnostic engineer would: classify the fault (or forecast one), retrieve relevant repair/safety knowledge, decide whether to escalate, and produce a structured, cited repair recommendation — without a human scripting each step. (The classifier's reframe from instant classification to forecasting is a Week 2 finding — see Section 4, Week 2, and `docs/Pitch_and_Explainer.md`'s "Reframing the classifier" section for the full story.)

This is designed to demonstrate, in one project:
- **Deep learning / transfer learning** (bootcamp requirement) — a fine-tuned fault classifier, plus pretrained Hugging Face embedding/generation models
- **Agentic AI** — an LLM-driven agent that orchestrates multiple tools and makes decisions, not a single-shot pipeline
- **GenAI** — grounded, cited natural-language generation (RAG)
- **Deployment & monitoring** — a live app with logged agent traces, not a notebook

**Target user (locked):**
- **Primary persona — Fleet maintenance manager.** Operates a fleet of vehicles (logistics/delivery/trucking), watching continuous telemetry rather than waiting for a code to fire. Question they ask the system: "This vehicle's readings are trending toward a fault — do I bring it in proactively, or is it fine?" This maps directly onto the classifier's forward-looking **Fault_Within_6h** forecast (built from the dataset's DTC-derived Fault Label — see Section 2 and the Week 2 reframe in Section 4) — itself a fleet-triage decision, just made before a fault exists rather than after. Use this persona as the headline demo narrative.
- **Secondary persona — Junior diagnostic engineer at an OEM/dealer.** Question they ask: "What's the root cause of this code, has it been seen before, is there a recall/bulletin, what's the repair procedure?" Same underlying agent output (classification + severity + cited NHTSA records + suggested repair steps) serves this persona too — mention it as a "this generalizes beyond one persona" line in the pitch, not as a second headline. Don't split the demo narrative across both; pick one voice for the story and note the other as an extension.
- **Important:** the system diagnoses and recommends — it does not perform the physical repair. It's a copilot for the human (fleet manager or engineer), who still makes the final call.

### Business goal & metric — locked (coach-approved, do not change again)

**Business goal:** the primary user is a fleet maintenance manager whose vehicles already have continuous telemetry logging installed, the same kind commercial fleets already run today for tracking and maintenance (e.g. Samsara, Geotab). The system watches that telemetry to forecast whether a fault is likely in the near future, so the manager can proactively schedule the vehicle in before it breaks down, rather than reactively waiting for a dashboard light. This hardware assumption does not hold for a walk-in service-center customer, whose vehicle typically has no continuous telemetry history, only a one-time OBD-II scan at the moment of the visit — that persona is downstream and reactive (see Section 1's secondary persona), and does not depend on the forecasting classifier at all.

**Metric:** `Fault_Within_6h`, binary, forecasting whether a fault occurs in the next 6 hours from rolling/lag sensor features, not instant classification of the current reading. Evaluated with macro F1 and per-class recall (not accuracy, which is meaningless under the severe class imbalance), on a chronological per-vehicle train/test split, not a random row split. Current baseline: macro F1 ≈ 0.60 (Random Forest), the honest number after the earlier instant-classification framing was found to be a near-tautological 1.000 (see Section 4, Week 2, and `docs/Pitch_and_Explainer.md`'s "Reframing the classifier" section for the full story).

This framing was reviewed and explicitly approved by the coach on 2026-07-28: *"You are absolutely right. Please align the business goal and metric accordingly. Once it is fixed, we no longer change it."* Treat this section as final — any future change to the target user, telemetry assumption, or evaluation metric needs to be revisited with the coach first, not made unilaterally.

## 2. Datasets (all public, no confidentiality issues)

**Subsystem (locked): Battery / EV.** Chosen over braking/engine cooling for the career-story fit (ties to Harsha's automotive/BMS background — see Section 7) after verifying the data risk was closed (see below).

| Purpose | Dataset | Notes |
|---|---|---|
| Fault/severity classifier training (primary) | [EV Sensors: Driving Pattern Diagnostics (2020-24) (Kaggle)](https://www.kaggle.com/datasets/kunalm95/ev-sensors-driving-pattern-diagnostics-2020-24) | 175,200 rows — 4 EVs × 5 years, hourly. Real named DTCs (`P0MR` motor RPM, `P0MT` motor temp, `P0T` general temp, `P0P` pressure, `P0B` battery, `P0S` SOC/SOH) alongside SOC/SOH/battery temp/motor RPM/torque/temp/brake wear/tire pressure sensors. Derive **Fault Label** = Normal / Warning / Fault from DTC presence/count/severity. 1.63% of rows carry any DTC — realistic imbalance, handling required in Week 2. **CC BY 4.0** (attribution only). Verified genuine signal: a Random Forest predicting fault-from-sensors gets AUC 0.9999 / F1 0.995, driven sensibly by Motor_RPM/Motor_Torque/Motor_Temp — matches the DTC names. |
| Fleet context / secondary sensor features | [Logistics Vehicle Maintenance History Dataset (Kaggle)](https://www.kaggle.com/datasets/datasetengineer/logistics-vehicle-maintenance-history-dataset) | 250,000 rows. Has explicit `Battery_Status`, `Brake_Condition`, `Engine_Temperature` columns and an EV vehicle type (Tesla Semi) alongside ICE trucks — use for fleet-level framing and the Normal/Minor/Major severity structure. |
| RAG knowledge corpus | [NHTSA Datasets & APIs](https://www.nhtsa.gov/nhtsa-datasets-and-apis) — recalls, complaints, manufacturer communications (TSBs) | Official, free, public domain, no auth required, updated daily. Filter to battery/electrical component tags (see verification below), not all recalls for an EV model. |

**Dataset swap (Week 1):** the originally planned primary dataset — *EV Battery and Drivetrain Fault Diagnosis* (`programmer3/ev-battery-and-drivetrain-fault-diagnosis`) — was removed from Kaggle sometime after this plan was written (404 on the dataset page, not in search, not among that user's current datasets). This took two rounds of evaluation to replace safely; full trial history, including a dataset that was briefly locked in and then reversed after failing a signal test, is documented in [`docs/Dataset_Selection_Log.md`](./Dataset_Selection_Log.md). Final choice: **EV Sensors: Driving Pattern Diagnostics** (see table above).

**Data risk verification (done):** queried the live NHTSA API directly before locking this in.
- Chevrolet Bolt EV, 2022: 7 recalls, including 2 explicit `ELECTRICAL SYSTEM:PROPULSION SYSTEM:TRACTION BATTERY` fire recalls (21V650, 24V481/24V812 follow-ups).
- Tesla Model 3, 2022: 17 recalls (mostly OTA software — useful for volume, but confirms need to filter by `Component` field for battery-relevance, not just "any EV recall").
- Volkswagen ID.4, 2023: 13 recalls, including 3 explicit `TRACTION BATTERY` fire recalls (25V836, 26V028, 26V030, from 2025–2026).
- Complaint volume per model-year is high enough that a single query (Tesla Model 3, one model year) exceeded a normal response size — complaints are not the scarcity risk.
- **Conclusion:** just 3 EV models across a few model-years already yield 37 real recall documents with genuine battery-specific content. Scaling to ~15–20 EV models × several model-years, filtered by component tag, should yield several hundred citable documents — enough for a real RAG corpus. The real Week 1 work is *curation* (filtering bulk recall/complaint data to battery/electrical component tags) rather than volume risk.

Do not use any VW/ASAP data, models, or documentation for this project (confidential IP) — note: the VW ID.4 recall data above is public NHTSA safety data, not VW internal/confidential data, so it's fine to use.

## 3. Architecture

```
Sensor/DTC input
      │
      ▼
[Streamlit app]
  ├── Agent Orchestrator (LLM + tool-calling, in-process)
  │     ├── Tool 1: classify_fault()      → fine-tuned classifier (trained model)
  │     ├── Tool 2: search_recalls_tsbs() → RAG over NHTSA corpus (pretrained HF embeddings)
  │     └── Tool 3: generate_ticket()     → LLM composes structured, cited repair ticket
  │
  ├── Dashboard (submit fault → view agent's reasoning trace → final ticket)
  │
  └── Logging/monitoring → Supabase/Postgres (success rate, escalation rate, latency)
```

**Architecture decision (updated from the original Next.js/Vercel/FastAPI split):** a single Streamlit app, not a separate frontend + backend. Locked in 2026-07-27 because the team (Ghada, Hüseyin, Harsha) knows Python from the bootcamp, not necessarily React/Next.js/JS tooling — a split stack would mean either double the surface area to learn in 4 weeks, or one person siloed on frontend while the rest can't touch it. The Streamlit app calls `classify_fault()` / `search_recalls_tsbs()` / `generate_ticket()` directly in-process and writes each run's log straight to Supabase — no separate REST API layer. Trade-off, stated explicitly: less "production microservice" separation of concerns than the original plan — acceptable for a 4-week capstone demo, where the agent's reasoning trace and grounded output matter more to evaluators than deployable-service boundaries.

**Stack:**
- Classifier: scikit-learn baseline → small neural net. **LSTM/RNN, not MLP/1D-CNN** (updated 2026-07-31 per coach suggestion — an LSTM carries a hidden state across the full sequence, a better fit for "has this vehicle been gradually trending toward trouble" than a 1D-CNN's local receptive field; see Week 2 below and `notebooks/04_lstm_classifier.ipynb` for the result), Python
- RAG: pretrained sentence-transformer (Hugging Face) embeddings, pgvector (Supabase) as the vector store
- Agent: simple function-calling loop (OpenAI/Anthropic function calling, or LangChain/LangGraph if the team wants the framework), called in-process from the Streamlit app
- App: Streamlit (single app — UI + agent + classifier + logging calls, no separate frontend/backend split)
- Deployment: Streamlit Community Cloud, deployed straight from the GitHub repo — no separate frontend/backend deploy pipeline to run
- Logging: Supabase/Postgres table storing each agent run's tool calls and outputs

Keep the tool count at 2–3. A fourth "mock service scheduling" tool is a nice-to-have — cut it first if time runs short.

## 4. Week-by-Week Plan

### Week 1 — Data & Foundations
- ~~Pick the target subsystem~~ — **done: Battery/EV, locked**
- ~~Pull and clean the primary classifier training dataset~~ (see Section 2 for the current dataset — the originally planned one was removed from Kaggle mid-Week-1 and replaced; full trial history in `docs/Dataset_Selection_Log.md`) — **done**
- ~~Pull NHTSA recalls + complaints for ~15–20 EV models (multiple model-years each) via the API; filter to battery/electrical component tags (`TRACTION BATTERY`, `ELECTRICAL SYSTEM`, etc.) rather than keeping every recall for an EV model~~ — **done** (202 recalls + 3,329 complaints filtered, `data/raw/nhtsa/`)
- ~~EDA notebook; define fault/severity classes clearly; check class balance on the Fault Label (Normal/Warning/Fault)~~ — **done** (`notebooks/01_eda.ipynb`; Normal 98.37% / Fault 1.51% / Warning 0.12% — more imbalanced than originally estimated)
- Repo scaffold — **done** (requirements.txt, src/, .env.example). Supabase project, Streamlit skeleton, team roles assigned — **not started**, need account setup + role decisions
- **Deliverable:** cleaned datasets, EDA notebook, working repo skeleton

### Week 2 — Train Classifier + Build RAG
- **Realistic product framing:** the classifier's input never comes from a human typing in sensor values — it comes automatically from the vehicle's existing telemetry feed (this is how real connected-fleet telematics already works). The only UI surface a person sees is the fault alert + agent diagnosis, never a 10-field data-entry form. For the demo (no live telemetry integration in scope), this gets simulated by replaying real held-out rows through the pipeline as if they arrived live — a documented scope decision, not an oversight.
- **Feature relevance, before finalizing the feature set:**
  - Rank the 10 sensor columns (`SOC`, `SOH`, `Charging_Cycles`, `Battery_Temp`, `Motor_RPM`, `Motor_Torque`, `Motor_Temp`, `Brake_Pad_Wear`, `Charging_Voltage`, `Tire_Pressure`) with `sklearn.feature_selection.mutual_info_classif` against `Fault_Label`, as a second, non-linear-aware check alongside the Random Forest importances already observed during dataset selection (`Motor_RPM`/`Motor_Torque`/`Motor_Temp` dominated there, consistent with the Fault-tier DTCs being motor/battery codes).
  - `Brake_Pad_Wear`, `Charging_Voltage`, and `Tire_Pressure` are expected to rank low for this Battery/EV-locked target (tire pressure in particular maps to a Warning-tier code, not Fault) — don't treat all 10 columns as equally important without checking.
  - **Feature-level leakage confirmed:** none of the 10 sensor columns are threshold/limit columns or otherwise mechanically derived from the `DTC` column itself (unlike the rejected 5-year EV battery candidate in `docs/Dataset_Selection_Log.md`, whose `*_limit_*` columns were explicitly excluded for this reason). Worth re-confirming this explicitly on the final dataset, not just inferring it from the candidate-selection process.
- Train baseline (Random Forest/XGBoost) then a small neural net classifier; evaluate with F1/confusion matrix, handle class imbalance
  - **Split methodology (decided in `notebooks/01_eda.ipynb` Section 8-9, not a random row split):** chronological, per-vehicle — hold out the most recent ~20% of each of the 4 vehicles' timelines as test. A random row-level split risks leaking adjacent-hour sensor autocorrelation between train/test even though fault episodes themselves turned out to be 95.7% single isolated hours, not multi-hour runs.
  - **Leakage discipline during training:** preprocessing and class-imbalance handling (class weighting) fit only on the training fold, then applied to test — never on the combined dataset. No SMOTE/resampling and no lag/rolling features were used for the Week 2 baseline.
  - **Evaluation:** report both the 3-class `Fault_Label` breakdown (Normal/Warning/Fault — matches the plan's triage framing) and a binary Normal-vs-Any-Issue rollup. `Warning` has only ~205 rows total (~40 in test) — treat its metrics as directional, not a confident estimate; the binary rollup is the statistically reliable headline number.
  - **Baseline result (instant-classification framing):** Random Forest macro F1 1.000, XGBoost 0.985 — see next bullet, this framing was superseded.
  - **Reframed per coach feedback (`notebooks/01b_sequence_features.ipynb`, `notebooks/03_sequence_classifier.ipynb`):** the coach correctly flagged that treating each hourly row as an independent classification sample ignores that this is 4 continuous per-vehicle time series — confirmed by the dataset's own Kaggle README, which states its intended use cases as time-series forecasting/anomaly detection, not row-level classification. Reframed the task from "classify this instant" to "forecast `Fault_Within_6h`" using per-vehicle rolling/lag features (6h/12h/24h rolling mean & std, 1h/3h/6h lags, 6h delta on Motor_RPM/Motor_Torque/Motor_Temp/Battery_Temp), verified with an explicit no-cross-vehicle-bleed check and a brute-force-verified target function. **Result: macro F1 dropped to ~0.60 (RF) / ~0.59 (XGBoost)** — a large, expected drop confirming the original 1.000 reflected an easy, near-tautological label rather than a leak. A confound hypothesis (`Brake_Pad_Wear`/`SOH` relevance = vehicle-identity artifact) was tested with permutation importance + per-vehicle mutual information and found **not confirmed** — genuine within-vehicle signal, reported honestly rather than forced to match the original guess. This ~0.60 macro F1 is the real Week 2 baseline going forward.
  - **Deep-learning step — LSTM, not MLP/1D-CNN (coach suggestion, `notebooks/04a_lstm_windows.ipynb` + `notebooks/04_lstm_classifier.ipynb`):** the coach reviewed the forecasting reframe and suggested an LSTM/RNN over the originally planned MLP/1D-CNN — the tree baselines already handle "recent history" via engineered rolling/lag features, but an LSTM can instead consume the **raw 24h sequence** directly and accumulate a gradual trend in its hidden state, which a 1D-CNN's local sliding window can't do as naturally. Built a small 2-layer LSTM (64/32 units) on raw sequences of `Motor_RPM`/`Motor_Torque`/`Motor_Temp`/`Battery_Temp`. **Result: macro F1 0.508 (below both tree baselines) but Fault-class recall 0.822 (above both)** — a genuine precision/recall tradeoff, not a clean win or loss; reported as-is rather than picking a "winner". Building this also surfaced and required fixing a real environment bug: `model.fit()` deadlocks in this Jupyter kernel if pandas, matplotlib/seaborn, or `sklearn.metrics` are imported anywhere earlier in the same kernel — worked around by splitting data prep (pandas) and model training (TensorFlow) into separate notebooks/kernel processes, documented in `04a_lstm_windows.ipynb`. Next steps (12h window, feature pruning around `Tire_Pressure`/`Charging_Voltage`) are open for Week 2 continuation or Week 3 if time allows.
- Chunk NHTSA text, embed with a pretrained Hugging Face sentence-transformer, load into pgvector
- Test retrieval quality manually on a handful of known queries
- **Deliverable:** trained classifier with metrics; working retrieval demo (input query → relevant NHTSA passages)

### Week 3 — Agent Orchestration
- Build the tool-calling agent loop combining classify → retrieve → generate, as functions called directly from the Streamlit app (no separate API service — see Section 3)
- Add guardrails: don't let the LLM invent remedies not present in retrieved text; handle empty-retrieval gracefully
- Log every agent run (tool calls, inputs/outputs, final ticket) to the database
- **Deliverable:** end-to-end agent (callable from a script or notebook) that takes a sensor input and produces a cited repair ticket

### Week 4 — Deployment, Evaluation, Presentation
- Build the dashboard (Streamlit): submit a fault → see the agent's step-by-step trace → see the final ticket; add a small "ops" view showing run counts/escalation rate/latency
- Deploy to Streamlit Community Cloud from the GitHub repo; smoke-test end to end
- Run a real evaluation: retrieval precision on a labeled set of test questions, classifier metrics, 5–10 documented end-to-end test cases (include at least one failure case and how the system handled it)
- Write the architecture README + prepare the presentation/demo script
- **Deliverable:** live deployed app, evaluation results, final presentation

## 5. Suggested Role Split (team of 3–4)

- **Data/Classifier owner:** dataset cleaning, feature engineering, model training/evaluation
- **RAG/Agent owner:** embeddings, vector store, tool-calling logic, guardrails
- **Frontend/Deployment owner:** dashboard, deployment, logging/monitoring
- **Eval/Docs owner** (or shared if team of 3): evaluation methodology, README, presentation

## 6. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Agent tool-calling is unreliable/buggy | Test each tool independently before composing; keep to 2–3 tools |
| Sensor dataset categories don't map to NHTSA corpus topics | Scope to one subsystem so both datasets align |
| Scope creep, doesn't ship in 4 weeks | Define a "must-have" floor (classifier + RAG + basic ticket) vs. "nice-to-have" (mock service tool, fancy ops dashboard) |
| NHTSA data pull/cleaning takes longer than expected | Start this in Week 1, not Week 2 |
| Demo looks like "just a chatbot" to evaluators | Explicitly show the agent's reasoning trace/tool calls in the UI, not just the final answer |

## 7. Why This Project

Ties Harsha's automotive/BMS/embedded background (authentic domain credibility) to the specific skills the 2026 AI job market is paying a premium for: agentic AI, RAG, and deployed/monitored systems — while remaining industry-agnostic in the underlying skill demonstrated, so it's pitchable beyond automotive roles too.
