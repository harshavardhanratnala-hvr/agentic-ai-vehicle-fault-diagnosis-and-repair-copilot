# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This repo is currently in the **Week 1 (Data & Foundations)** stage of a 4-week capstone. `src/` and `notebooks/` are empty scaffolding — there is no build, lint, or test tooling yet because no code has been written. Do not assume a stack is installed; check for a `requirements.txt`/`pyproject.toml` or `package.json` before running any command, and create one as part of the first real implementation task if it's missing.

The single source of truth for scope, architecture, and the week-by-week plan is **`docs/Capstone_Project_Plan.md`**. Read it in full before starting any implementation work — this file only summarizes it. If the plan changes (scope, datasets, subsystem, architecture), edit `docs/Capstone_Project_Plan.md` directly rather than letting decisions live only in chat or commit messages.

## Project management

Work is tracked as GitHub Issues on this repo, organized into 4 milestones (`Week 1 - Data & Foundations`, `Week 2 - Classifier & RAG`, `Week 3 - Agent Orchestration`, `Week 4 - Deployment & Evaluation`) and a Kanban project board ("Vehicle Fault Copilot - Capstone Board"). Labels map to workstreams: `data`, `classifier`, `rag`, `agent`, `frontend`, `deployment`, `eval`, `docs`. When picking up work, check the relevant milestone's open issues rather than re-deriving tasks from the plan doc. `scripts/github_setup.sh` documents the original issue backlog (already created) and `docs/PROJECT_BOARD_SETUP.md` documents the board's workflow conventions (milestone = sprint, label = workstream, WIP limit of 1-2 in-progress issues).

## Architecture (per the plan)

The system is a tool-calling LLM agent, not a single-shot pipeline:

```
Sensor/DTC input → Agent Orchestrator (LLM + tool-calling)
  ├── classify_fault()      → fine-tuned classifier (trained model)
  ├── search_recalls_tsbs() → RAG over NHTSA corpus (pretrained HF embeddings)
  └── generate_ticket()     → LLM composes structured, cited repair ticket
→ Dashboard (submit fault → agent's reasoning trace → final ticket)
→ Logging/monitoring (success rate, escalation rate, latency)
```

Keep the tool count at 2-3; a 4th "mock service scheduling" tool is explicitly a cut-first nice-to-have if time is short.

**Subsystem is locked to Battery/EV.** The classifier trains on the EV Battery and Drivetrain Fault Diagnosis dataset (target: `Fault Label` = Normal/Warning/Fault, ~6% Fault class — class imbalance handling is required, not optional). The RAG corpus is NHTSA recall/complaint/TSB data filtered to battery/electrical component tags (`TRACTION BATTERY`, `ELECTRICAL SYSTEM`), not all recalls for a given EV model — over-broad filtering was explicitly identified as a risk in the plan. Full dataset details and the verified NHTSA data-volume numbers are in `docs/Capstone_Project_Plan.md` Section 2.

Suggested stack (not yet installed): scikit-learn → small neural net (MLP/1D-CNN) for the classifier; sentence-transformers + pgvector (Supabase) for RAG; Next.js frontend; FastAPI backend; Vercel + GCP Cloud Run for deployment.

## Repo layout

- `docs/` — plan, pitch materials, project board setup guide
- `notebooks/` — EDA and experimentation (empty so far)
- `src/` — classifier, RAG pipeline, agent, API (empty so far)
- `slides/` — presentation decks
- `media/` — demo videos/screenshots (`.mp4`/`.mov` gitignored)
- `data/` — local datasets, gitignored except `.gitkeep` — never commit raw data files here

## Key constraint from the plan

Do not use any VW/ASAP data, models, or documentation (confidential IP). The VW ID.4 NHTSA recall data referenced in the plan is public safety data, not VW internal data, and is fine to use.
