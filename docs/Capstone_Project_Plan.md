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

| Purpose | Dataset | Notes |
|---|---|---|
| Fault/severity classifier training | [Logistics Vehicle Maintenance History Dataset (Kaggle)](https://www.kaggle.com/datasets/datasetengineer/logistics-vehicle-maintenance-history-dataset) | Sensor measurements, diagnostic signals, multiclass target (Normal / Minor Maintenance / Major Maintenance) |
| Additional sensor features | OBD-II Dataset (Kaggle) | ~47,514 rows, 33 features — engine load, RPM, coolant temp, etc. |
| RAG knowledge corpus | [NHTSA Datasets & APIs](https://www.nhtsa.gov/nhtsa-datasets-and-apis) — recalls, complaints, technical service bulletins | Official, free, public domain, no auth required, updated daily |

**Important scoping decision:** pick ONE vehicle subsystem (e.g., braking, battery/EV, or engine cooling) so the classifier's fault categories and the NHTSA text corpus actually overlap. Trying to cover "all vehicle faults" will dilute both the model and the RAG corpus.

Do not use any VW/ASAP data, models, or documentation for this project (confidential IP).

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
- Pick the target subsystem (e.g., braking or battery)
- Pull and clean the Kaggle sensor/maintenance dataset; pull NHTSA recalls/complaints/TSBs for that subsystem via the API
- EDA notebook; define fault/severity classes clearly
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
