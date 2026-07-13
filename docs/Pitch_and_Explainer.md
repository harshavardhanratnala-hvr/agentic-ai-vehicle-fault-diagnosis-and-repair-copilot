# Agentic AI Vehicle Fault Diagnosis & Repair Copilot — Pitch & Explainer

## The problem

Cars constantly throw off signals that something might be wrong — a diagnostic trouble code, a weird sensor reading (temperature, vibration, voltage, whatever). Today, turning that raw signal into "here's what's wrong and here's how to fix it" requires a human mechanic or engineer to interpret it, often by cross-referencing manufacturer bulletins and recall databases. That's slow and inconsistent.

## What we're building

An AI "copilot" that does that interpretation automatically. Feed it a fault signal, and it:

1. Classifies what kind of fault it likely is and how serious.
2. Looks up real government safety records (NHTSA recalls, complaints, technical bulletins) about that specific issue.
3. Writes up a clear repair recommendation that cites those real records instead of making things up.

You watch it think through each step, not just spit out an answer.

## Why "agentic" matters here (the novel part)

A basic version would be one model doing one thing. This instead has an AI that decides which tools to call and in what order — like a junior engineer who knows to check the sensor reading, then look up the bulletins, then write the ticket — rather than a fixed script. That's the "agentic AI" skill that's in demand right now, on top of the more standard "train a classifier" and "do RAG" pieces.

## One-sentence pitch for a general audience

> "We built an AI mechanic's assistant — you give it a car's warning signal, and it automatically figures out what's likely wrong, pulls up real recall and repair records for that exact problem, and writes a diagnosis you can trust because it shows its sources."

## The scope, concretely, in 4 weeks

- One vehicle subsystem only (braking, or battery/EV, or engine cooling — not "all car problems," that's too broad).
- A small trained classifier.
- A search system over NHTSA's public repair records.
- An AI agent that chains those two together and writes the final report.
- A simple web dashboard to demo it.

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

## Sources

- [Automated vehicle fault diagnosis and report generation using hybrid machine learning with multi-step RAG approach](https://link.springer.com/article/10.1007/s10791-025-09823-8)
- [Vehicle Recalls & Common Problems Database — NHTSA Data | MECH AI](https://mechai.app/diagnose/recalls/)
- [Recall Recon: A Machine Learning and RAG-Based System for Forecasting Automotive Safety Recalls](https://medium.com/99p-labs/recall-recon-a-machine-learning-and-rag-based-system-for-forecasting-automotive-safety-recalls-29f5d858385f)
