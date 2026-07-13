# Capstone Project Plan: Agentic AI Vehicle Fault Diagnosis & Repair Copilot

**Team:** Harsha Vardhan Ratnala + capstone teammates
**Program:** neue fische Data Science & AI Bootcamp
**Duration:** 4 weeks

## 1. Concept

An agentic AI system that takes a vehicle fault trigger (a diagnostic trouble code or an anomalous sensor reading), and works the problem autonomously the way a diagnostic engineer would: classify the fault, retrieve relevant repair/safety knowledge, decide whether to escalate, and produce a structured, cited repair recommendation — without a human scripting each step.

This is designed to demonstrate, in one project:
- **Deep learning / transfer learning** (bootcamp requirement) — a fine-tuned fault classifier, plus pretrained Hugging Face embedding/generation models
- **Agentic AI** — an LLM-driven agent that orchestrates multiple tools and makes decisions, not a single-shot pipeline
- **GenAI** — grounded, cited natural-language generation (RAG)
- **Deployment & monitoring** — a live app with logged agent traces, not a notebook

**Target user (locked):**
- **Primary persona — Fleet maintenance manager.** Operates a fleet of vehicles (logistics/delivery/trucking). Question they ask the system: "This truck just threw a fault signal — is it safe to keep driving, or do I pull it in now?" This maps directly onto the Kaggle dataset's target classes (Normal / Minor Maintenance / Major Maintenance), which are themselves a fleet-triage decision. Use this persona as the headline demo narrative.
- **Secondary persona — Junior diagnostic engineer at an OEM/dealer.** Question they ask: "What's the root cause of this code, has it been seen before, is there a recall/bulletin, what's the repair procedure?" Same underlying agent output (classification + severity + cited NHTSA records + suggested repair steps) serves this persona too — mention it as a "this generalizes beyond one persona" line in the pitch, not as a second headline. Don't split the demo narrative across both; pick one voice for the story and note the other as an extension.
- **Important:** the system diagnoses and recommends — it does not perform the physical repair. It's a copilot for the human (fleet manager or engineer), who still makes the final call.

## 2. Datasets (all public, no confidentiality issues)

**Subsystem (locked): Battery / EV.** Chosen over braking/engine cooling for the career-story fit (ties to Harsha's automotive/BMS background — see Section 7) after verifying the data risk was closed (see below).

| Purpose | Dataset | Notes |
|---|---|---|
| Fault/severity classifier training (primary) | [EV Battery and Drivetrain Fault Diagnosis (Kaggle)](https://www.kaggle.com/datasets/programmer3/ev-battery-and-drivetrain-fault-diagnosis) | ~237,000 rows, 10 columns (voltage, current, temperature, motor speed, SOC estimate vs. ground truth, residual). Target: **Fault Label** = Normal / Warning / Fault. CC0 public domain. Fault class is ~6% of rows — plan for class-imbalance handling in Week 2. |
| Fleet context / secondary sensor features | [Logistics Vehicle Maintenance History Dataset (Kaggle)](https://www.kaggle.com/datasets/datasetengineer/logistics-vehicle-maintenance-history-dataset) | 250,000 rows. Has explicit `Battery_Status`, `Brake_Condition`, `Engine_Temperature` columns and an EV vehicle type (Tesla Semi) alongside ICE trucks — use for fleet-level framing and the Normal/Minor/Major severity structure. |
| RAG knowledge corpus | [NHTSA Datasets & APIs](https://www.nhtsa.gov/nhtsa-datasets-and-apis) — recalls, complaints, manufacturer communications (TSBs) | Official, free, public domain, no auth required, updated daily. Filter to battery/electrical component tags (see verification below), not all recalls for an EV model. |

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
[Agent Orchestrator (LLM + tool-calling)]
      │
      ├── Tool 1: classify_fault()      → fine-tuned classifier (trained model)
      ├── Tool 2: search_recalls_tsbs() → RAG over NHTSA corpus (pretrained HF embeddings)
      └── Tool 3: generate_ticket()     → LLM composes structured, cited repair ticket
      │
      ▼
Dashboard (submit fault → view agent's reasoning trace → final ticket)
      │
      ▼
Logging/monitoring (success rate, escalation rate, latency)
```

**Stack suggestion:**
- Classifier: scikit-learn baseline → small neural net (MLP/1D-CNN), Python
- RAG: pretrained sentence-transformer (Hugging Face) embeddings, pgvector (Supabase) as the vector store
- Agent: simple function-calling loop (OpenAI/Anthropic function calling, or LangChain/LangGraph if the team wants the framework)
- Frontend: Next.js (reuse Harsha's existing stack)
- Backend: Python (FastAPI) hosting the agent + classifier
- Deployment: Vercel (frontend) + GCP Cloud Run (backend)
- Logging: Supabase/Postgres table storing each agent run's tool calls and outputs

Keep the tool count at 2–3. A fourth "mock service scheduling" tool is a nice-to-have — cut it first if time runs short.

## 4. Week-by-Week Plan

### Week 1 — Data & Foundations
- ~~Pick the target subsystem~~ — **done: Battery/EV, locked**
- Pull and clean the EV Battery and Drivetrain Fault Diagnosis dataset (primary classifier training data)
- Pull NHTSA recalls + complaints for ~15–20 EV models (multiple model-years each) via the API; filter to battery/electrical component tags (`TRACTION BATTERY`, `ELECTRICAL SYSTEM`, etc.) rather than keeping every recall for an EV model
- EDA notebook; define fault/severity classes clearly; check class balance on the Fault Label (Normal/Warning/Fault)
- Repo scaffold, Supabase project, Vercel skeleton, team roles assigned
- **Deliverable:** cleaned datasets, EDA notebook, working repo skeleton

### Week 2 — Train Classifier + Build RAG
- Train baseline (Random Forest/XGBoost) then a small neural net classifier; evaluate with F1/confusion matrix, handle class imbalance
- Chunk NHTSA text, embed with a pretrained Hugging Face sentence-transformer, load into pgvector
- Test retrieval quality manually on a handful of known queries
- **Deliverable:** trained classifier with metrics; working retrieval demo (input query → relevant NHTSA passages)

### Week 3 — Agent Orchestration
- Build the tool-calling agent loop combining classify → retrieve → generate
- Add guardrails: don't let the LLM invent remedies not present in retrieved text; handle empty-retrieval gracefully
- Log every agent run (tool calls, inputs/outputs, final ticket) to the database
- **Deliverable:** end-to-end agent (CLI or simple API) that takes a sensor input and produces a cited repair ticket

### Week 4 — Deployment, Evaluation, Presentation
- Build the dashboard: submit a fault → see the agent's step-by-step trace → see the final ticket; add a small "ops" view showing run counts/escalation rate/latency
- Deploy frontend + backend; smoke-test end to end
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
