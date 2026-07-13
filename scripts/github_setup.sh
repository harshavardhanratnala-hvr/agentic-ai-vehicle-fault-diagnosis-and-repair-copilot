#!/usr/bin/env bash
# One-time setup: creates labels, milestones, and the full Week 1-4 issue backlog
# on GitHub via the gh CLI, so you can manage this project with real GitHub
# Issues + a Projects board instead of a chat todo list.
#
# Prereqs (run these yourself first):
#   1. Install gh: https://cli.github.com
#   2. gh auth login
#   3. Push this repo to GitHub (see docs/PROJECT_BOARD_SETUP.md), then run this
#      script from inside the repo folder.
#
# Usage:
#   chmod +x scripts/github_setup.sh
#   ./scripts/github_setup.sh

set -e

echo "== Creating labels =="
gh label create "data"        --color "0E8A16" --description "Dataset pulling/cleaning" --force
gh label create "classifier"  --color "1D76DB" --description "Fault classifier work"     --force
gh label create "rag"         --color "5319E7" --description "RAG / retrieval work"       --force
gh label create "agent"       --color "B60205" --description "Agent orchestration"        --force
gh label create "frontend"    --color "FBCA04" --description "Dashboard / UI"             --force
gh label create "deployment"  --color "0052CC" --description "Deploy / infra"             --force
gh label create "eval"        --color "D93F0B" --description "Evaluation / testing"       --force
gh label create "docs"        --color "C5DEF5" --description "Documentation / writeup"    --force

echo "== Creating milestones =="
gh api repos/:owner/:repo/milestones -f title="Week 1 - Data & Foundations"        -f state="open" || true
gh api repos/:owner/:repo/milestones -f title="Week 2 - Classifier & RAG"          -f state="open" || true
gh api repos/:owner/:repo/milestones -f title="Week 3 - Agent Orchestration"       -f state="open" || true
gh api repos/:owner/:repo/milestones -f title="Week 4 - Deployment & Evaluation"   -f state="open" || true

create_issue() {
  local title="$1" body="$2" milestone="$3" labels="$4"
  gh issue create --title "$title" --body "$body" --milestone "$milestone" --label "$labels"
}

echo "== Week 1 issues =="
create_issue "Pull & clean EV Battery and Drivetrain Fault Diagnosis dataset" \
  "Primary classifier training data (~237k rows, Normal/Warning/Fault labels). Clean, dedupe, sanity-check ranges." \
  "Week 1 - Data & Foundations" "data"
create_issue "Pull & filter NHTSA recalls/complaints for battery/EV component tags" \
  "Query recalls + complaints API across ~15-20 EV models, multiple model-years each. Filter to TRACTION BATTERY / ELECTRICAL SYSTEM component tags rather than keeping every recall for an EV model." \
  "Week 1 - Data & Foundations" "data,rag"
create_issue "EDA notebook: fault/severity class distributions" \
  "Explore EV Battery Fault Diagnosis dataset. Confirm Fault Label class balance (Fault ~6% expected) and flag imbalance handling needed for Week 2." \
  "Week 1 - Data & Foundations" "data"
create_issue "Repo scaffold finalization" \
  "Confirm docs/notebooks/src/slides/media/data folder structure, requirements.txt or pyproject, .env.example." \
  "Week 1 - Data & Foundations" "docs"
create_issue "Set up Supabase project (vector store + logging DB)" \
  "Create Supabase project, enable pgvector extension, create table schema for agent run logs." \
  "Week 1 - Data & Foundations" "deployment"
create_issue "Set up Vercel skeleton (frontend placeholder)" \
  "Bare Next.js app deployed to Vercel as a placeholder, confirms deploy pipeline works early." \
  "Week 1 - Data & Foundations" "frontend,deployment"
create_issue "Assign team roles" \
  "Data/Classifier owner, RAG/Agent owner, Frontend/Deployment owner, Eval/Docs owner (see plan Section 5)." \
  "Week 1 - Data & Foundations" "docs"

echo "== Week 2 issues =="
create_issue "Train baseline classifier (RF/XGBoost)" \
  "Baseline on EV Battery Fault Diagnosis dataset before the neural net." \
  "Week 2 - Classifier & RAG" "classifier"
create_issue "Train small neural net classifier (MLP)" \
  "Compare against baseline. Report F1/confusion matrix." \
  "Week 2 - Classifier & RAG" "classifier"
create_issue "Handle class imbalance on Fault label" \
  "Fault is ~6% of rows. Try class weighting, SMOTE, or threshold tuning; document what was tried." \
  "Week 2 - Classifier & RAG" "classifier"
create_issue "Chunk NHTSA text corpus" \
  "Split filtered recall/complaint/TSB text into retrieval-sized chunks." \
  "Week 2 - Classifier & RAG" "rag"
create_issue "Embed corpus with pretrained HF sentence-transformer" \
  "Pick a pretrained embedding model, embed all chunks." \
  "Week 2 - Classifier & RAG" "rag"
create_issue "Load embeddings into pgvector" \
  "Store chunk embeddings + metadata (source recall ID, component, date) in Supabase pgvector table." \
  "Week 2 - Classifier & RAG" "rag,deployment"
create_issue "Manually test retrieval quality" \
  "Run a handful of known battery-fault queries, confirm the right NHTSA passages come back." \
  "Week 2 - Classifier & RAG" "rag,eval"

echo "== Week 3 issues =="
create_issue "Design tool-calling agent loop" \
  "classify -> retrieve -> generate, with decision logic for when to call what." \
  "Week 3 - Agent Orchestration" "agent"
create_issue "Implement classify_fault() tool" \
  "Wraps the trained classifier as an agent-callable tool." \
  "Week 3 - Agent Orchestration" "agent,classifier"
create_issue "Implement search_recalls_tsbs() tool" \
  "Wraps the RAG retrieval as an agent-callable tool." \
  "Week 3 - Agent Orchestration" "agent,rag"
create_issue "Implement generate_ticket() tool" \
  "LLM composes the structured, cited repair ticket from classify + retrieve outputs." \
  "Week 3 - Agent Orchestration" "agent"
create_issue "Add guardrails" \
  "Don't let the LLM invent remedies not present in retrieved text; handle empty-retrieval gracefully (escalate instead)." \
  "Week 3 - Agent Orchestration" "agent"
create_issue "Log every agent run to the database" \
  "Tool calls, inputs/outputs, final ticket -> Supabase logging table." \
  "Week 3 - Agent Orchestration" "agent,deployment"

echo "== Week 4 issues =="
create_issue "Build dashboard UI" \
  "Submit a fault -> see agent's step-by-step trace -> see final ticket." \
  "Week 4 - Deployment & Evaluation" "frontend"
create_issue "Build ops view" \
  "Run counts, escalation rate, latency, in a small dashboard panel." \
  "Week 4 - Deployment & Evaluation" "frontend,eval"
create_issue "Deploy frontend + backend" \
  "Vercel (frontend) + Cloud Run (backend). Smoke-test end to end." \
  "Week 4 - Deployment & Evaluation" "deployment"
create_issue "Run retrieval precision evaluation" \
  "Labeled set of test questions, measure retrieval precision." \
  "Week 4 - Deployment & Evaluation" "eval"
create_issue "Document 5-10 end-to-end test cases" \
  "Include at least one failure case and how the system handled it." \
  "Week 4 - Deployment & Evaluation" "eval,docs"
create_issue "Write architecture README" \
  "Full system writeup for anyone evaluating the repo." \
  "Week 4 - Deployment & Evaluation" "docs"
create_issue "Prepare presentation/demo script" \
  "Final capstone presentation + live/recorded demo walkthrough." \
  "Week 4 - Deployment & Evaluation" "docs"

echo "Done. Now create a Projects (v2) board from the repo's Projects tab and add these issues (see docs/PROJECT_BOARD_SETUP.md)."
