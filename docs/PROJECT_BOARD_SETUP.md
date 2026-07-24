# Setting Up the GitHub Project Board

This repo is already a local git repository. These steps get it onto GitHub with a full
Kanban board and issue backlog, so you can run this capstone with real project-management
tooling instead of a chat todo list.

I can't do this part for you — creating a GitHub account/repo and authenticating is
something only you should do (credential handling). Everything below is copy-paste
commands you run yourself, in your own terminal, in this folder.

## 1. Create the GitHub repo

1. Go to github.com → New repository.
2. Name it `agentic-ai-vehicle-fault-diagnosis-and-repair-copilot` (or whatever you prefer).
3. **Do not** initialize with a README/.gitignore/license — this repo already has those.
4. Create it, then copy the remote URL it gives you (HTTPS or SSH).

## 2. Push this repo

From inside this folder:

```bash
git remote add origin <the-url-you-copied>
git branch -M main
git push -u origin main
```

(If your default branch is already `main`, skip the `git branch -M main` step. If it's
`master`, the command above renames it to `main` before pushing, which matches GitHub's
default.)

## 3. Install and authenticate the GitHub CLI

```bash
# macOS
brew install gh
gh auth login
```

Follow the prompts (browser login is easiest). This is the one place you enter your own
GitHub credentials — I never see or touch them.

## 4. Create labels, milestones, and the issue backlog

```bash
chmod +x scripts/github_setup.sh
./scripts/github_setup.sh
```

This creates 8 labels (`data`, `classifier`, `rag`, `agent`, `frontend`, `deployment`,
`eval`, `docs`), 4 milestones (one per week), and ~28 issues pulled directly from
`docs/Capstone_Project_Plan.md`'s Week 1-4 plan, each tagged with its milestone and
labels.

## 5. Create the Kanban board

1. On your repo page, click the **Projects** tab → **New project** → choose the **Board**
   template.
2. Add columns: `Backlog`, `To Do`, `In Progress`, `Done` (the template gives you a
   starting set — rename/add as needed).
3. Click **Add item** → search and add all the issues the script created (or use the
   "Add items" bulk option and filter by repo).
4. Set the board's **auto-add workflow** (Project settings → Workflows) so new issues
   land in `Backlog` automatically, and closing an issue moves it to `Done` automatically.

## 6. How to actually use it week to week

- At the start of each week, drag that week's milestone issues from `Backlog` into `To Do`.
- When you start one, drag it to `In Progress` (or `gh issue edit <number> --add-assignee @me`
  and move it yourself) — never have more than 1-2 cards in `In Progress` per person at once,
  that's the whole point of a Kanban limit.
- Close the issue (`gh issue close <number>` or the checkbox in the UI) when it's actually
  done, not just "mostly done" — this is what makes the burndown/velocity meaningful later.
- At the end of each week, look at the milestone progress bar (repo → Issues → Milestones)
  to see real completion %, and use that in your standup/retro with teammates.

This mirrors how real engineering teams run sprints: milestone = sprint, label = workstream,
board columns = state, issue = unit of work. Everything here traces back to
`docs/Capstone_Project_Plan.md`, so if the plan changes, update the plan first and then
add/edit issues to match — the plan stays the source of truth.

## 7. Getting the data

`data/` is gitignored, so cloning the repo does not give teammates any of the actual
files. There are two different kinds of data here, and they need two different fixes.

**Public, reproducible data (Kaggle) — redownload it, don't transfer it.**
This is the raw EV driving-pattern/diagnostics dataset. Anyone can regenerate it exactly,
so the right move is to fetch it fresh rather than pass files around:

```bash
pip install kaggle
# then place your kaggle.json API token in ~/.kaggle/ (kaggle.com -> Account -> Create New API Token)
kaggle datasets download -d kunalm95/ev-sensors-driving-pattern-diagnostics-2020-24
unzip ev-sensors-driving-pattern-diagnostics-2020-24.zip -d data/raw/driving_pattern_diagnostics
```

**Custom-derived data — needs a shared link, because it can't be regenerated with one command.**
This is the cleaned CSV and the filtered NHTSA corpus. Only the person who built them has
the exact files, so they need to go up to a shared drive:

1. Go to [drive.google.com](https://drive.google.com) (or Dropbox, whichever you already use).
2. Create a new folder, e.g. `Bolt Capstone Data` (or `Vehicle Fault Copilot Data`).
3. Upload exactly these files/folders from your local `data/`:
   - `data/processed/driving_pattern_diagnostics_cleaned.csv`
   - `data/raw/nhtsa/` (the whole folder — `recalls_battery_electrical.csv`,
     `complaints_battery_electrical.csv`, `recalls_raw.json`, `complaints_raw.json`)
   - Do **not** upload the raw `data/raw/driving_pattern_diagnostics/` CSVs — teammates get
     those via the Kaggle command above instead.
   - The three `logistics_*` CSVs in `data/raw/` are leftover from earlier dataset
     exploration and aren't part of the current Battery/EV scope — no need to share those.
4. Right-click the folder → **Share** → set access to "Anyone with the link" (Viewer is
   enough) → **Copy link**.
5. Paste that link here once it exists, and share it with the team in your usual channel
   (Slack/Discord/etc).
6. Teammates: download the folder, then place its contents at the matching paths shown
   above relative to the repo root (`data/processed/...`, `data/raw/nhtsa/...`) so the
   notebooks/scripts find them without any path changes.

_Shared data link: https://drive.google.com/drive/folders/1aJGqBF6QGjHpCxvL5Dpfi9t_AuMcJBpD?usp=share_link_
