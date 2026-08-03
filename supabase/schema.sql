-- Vehicle Fault Copilot — Supabase schema
--
-- Run this once, in full, in the Supabase project's SQL Editor (Dashboard -> SQL Editor ->
-- New query -> paste -> Run). See docs/SUPABASE_SETUP.md for the full setup walkthrough.
--
-- Two tables, matching docs/Capstone_Project_Plan.md Section 3:
--   1. nhtsa_documents — the RAG vector store (search_recalls_tsbs() tool, issues #11-14)
--   2. agent_runs      — the logging table (issue #20), one row per end-to-end agent run

-- 1. Enable pgvector (bundled with Supabase, just needs turning on per-project)
create extension if not exists vector;

-- 2. RAG vector store: chunked NHTSA recalls/complaints + their embeddings
--
-- embedding dimension is 384, matching all-MiniLM-L6-v2 (the default pretrained
-- sentence-transformer named in the plan) -- if a different embedding model is chosen in
-- issue #12, change the dimension below to match before running any inserts.
create table if not exists nhtsa_documents (
  id uuid primary key default gen_random_uuid(),
  source_type text not null check (source_type in ('recall', 'complaint')),
  make text,
  model text,
  model_year int,
  campaign_number text,           -- recalls only (NHTSACampaignNumber); null for complaints
  component text,                 -- e.g. "ELECTRICAL SYSTEM:PROPULSION SYSTEM:TRACTION BATTERY"
  chunk_text text not null,       -- the actual text chunk that was embedded
  chunk_index int not null,       -- position of this chunk within its source document
  embedding vector(384) not null,
  metadata jsonb not null default '{}'::jsonb,  -- raw source fields not modeled above
  created_at timestamptz not null default now()
);

-- Vector similarity index (HNSW -- Supabase's currently recommended pgvector index type).
-- At this corpus's actual scale (~3,500 filtered NHTSA records, likely tens of thousands of
-- chunks after splitting) a sequential scan would already be fast; this index is future-proofing
-- and standard practice, not a requirement for correctness at this size.
create index if not exists nhtsa_documents_embedding_idx
  on nhtsa_documents using hnsw (embedding vector_cosine_ops);

create index if not exists nhtsa_documents_component_idx on nhtsa_documents (component);

-- RPC function for similarity search -- the Supabase client libraries (Python/JS) can't do
-- vector math themselves, so pgvector search is exposed as a Postgres function and called via
-- `.rpc("match_nhtsa_documents", {...})` instead of a plain table query.
create or replace function match_nhtsa_documents(
  query_embedding vector(384),
  match_count int default 5,
  filter_component text default null
)
returns table (
  id uuid,
  source_type text,
  make text,
  model text,
  model_year int,
  campaign_number text,
  component text,
  chunk_text text,
  metadata jsonb,
  similarity float
)
language sql stable
as $$
  select
    id, source_type, make, model, model_year, campaign_number, component, chunk_text, metadata,
    1 - (embedding <=> query_embedding) as similarity
  from nhtsa_documents
  where filter_component is null or component ilike '%' || filter_component || '%'
  order by embedding <=> query_embedding
  limit match_count;
$$;

-- 3. Agent run logging: one row per end-to-end agent invocation
--
-- tool_calls captures the full reasoning trace (ordered list of {tool, input, output,
-- timestamp}) -- what the dashboard's "view agent's reasoning trace" panel reads from.
create table if not exists agent_runs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  input jsonb not null,                  -- the triggering sensor reading or DTC
  classify_result jsonb,                 -- classify_fault() output
  retrieved_documents jsonb,             -- search_recalls_tsbs() output (matched doc ids/snippets)
  generated_ticket text,                 -- generate_ticket() output
  tool_calls jsonb not null default '[]'::jsonb,  -- full ordered reasoning trace
  escalated boolean not null default false,
  success boolean not null default true,
  latency_ms int,
  error_message text                     -- populated when success = false
);

create index if not exists agent_runs_created_at_idx on agent_runs (created_at desc);
