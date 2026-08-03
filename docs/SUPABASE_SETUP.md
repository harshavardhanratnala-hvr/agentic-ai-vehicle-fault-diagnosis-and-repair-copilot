# Setting Up Supabase (Vector Store + Agent Run Logging)

This gets the project's two Supabase-backed pieces running, per `docs/Capstone_Project_Plan.md`
Section 3: the `nhtsa_documents` table (the RAG vector store `search_recalls_tsbs()` will search)
and the `agent_runs` table (where every end-to-end agent run gets logged — issue #20).

I can't do this part for you — creating a Supabase account and a project is an account-level
action, same as the GitHub repo and Kaggle account earlier in this project. Everything below is
copy-paste steps you run yourself, in your own browser/terminal.

## 1. Create the Supabase project

1. Go to [supabase.com](https://supabase.com) → sign up (GitHub login is easiest) → **New project**.
2. Pick any project name (e.g. `vehicle-fault-copilot`), a database password (save it — you'll
   need it for the direct connection string later), and the free tier / a region close to you.
3. Wait for provisioning (a minute or two). You'll land on the project dashboard.

## 2. Run the schema

1. In the project dashboard, open **SQL Editor** (left sidebar) → **New query**.
2. Open `supabase/schema.sql` in this repo, copy its full contents, paste into the editor, and
   click **Run**.
3. This does three things in one go: enables the `pgvector` extension, creates `nhtsa_documents`
   (the vector store, 384-dim embeddings to match the plan's `all-MiniLM-L6-v2` default — change
   the dimension in the SQL first if issue #12 ends up picking a different embedding model) and
   `agent_runs` (the logging table), and creates a `match_nhtsa_documents` SQL function that the
   Python client calls for similarity search (the client libraries don't do vector math
   themselves, so pgvector search is exposed as a Postgres function instead of a plain query).
4. Sanity check: **Table Editor** (left sidebar) should now show `nhtsa_documents` and
   `agent_runs`, both empty — that's expected, nothing has been inserted yet.

## 3. Get credentials into `.env`

1. In the dashboard: **Project Settings** (gear icon) → **API**.
   - Copy **Project URL** → `SUPABASE_URL` in your `.env`.
   - Copy the **`service_role`** key (not the `anon` key — the service role key bypasses row-level
     security, which is fine here since this is a backend-only script/agent, not a public-facing
     app with untrusted users) → `SUPABASE_SERVICE_ROLE_KEY` in your `.env`.
2. **Project Settings → Database → Connection string** → copy the **URI** (choose "Session
   pooler" if given a choice, simplest for a script that isn't running many concurrent
   connections) → paste into `DATABASE_URL` in your `.env`, then substitute in the database
   password you set in Step 1 where the string shows `[YOUR-PASSWORD]`.
3. `.env` should now have all three filled in (see `.env.example` for the exact variable names).
   `.env` is gitignored — never commit it.

## 4. What plugs in here later (not part of this setup)

- **Issue #11/#12** (chunk + embed the NHTSA corpus) will insert rows into `nhtsa_documents` —
  reads from `data/raw/nhtsa/*.csv`, chunks the recall/complaint text, embeds each chunk, and
  writes rows matching the schema above.
- **Issue #16-18** (agent tools) will call `search_recalls_tsbs()`, which queries
  `match_nhtsa_documents` via the Supabase Python client's `.rpc()` method.
- **Issue #20** (agent run logging) will insert one row into `agent_runs` per end-to-end run.

None of that code exists yet — this setup just gets the database ready for it, so whoever picks
up those issues isn't also blocked on creating the project from scratch.
