# Testing — Peponi Omarchy helper

## 1. Local mode (no peponi.to account)

```bash
export PATH="$PWD/bin:$HOME/.local/bin:$PATH"
export PEPONI_CONFIG_DIR="$(mktemp -d)"
export PEPONI_DATA_DIR="$(mktemp -d)"

peponi auth local
peponi auth status --json
peponi add $(date +%F) "Buy milk"
peponi tick $(peponi day $(date +%F) --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["tasks"][0]["id"])')
peponi move 1 down
peponi pref roll-over off
peponi day $(date +%F) --json
peponi rm 1
peponi not-yet --json
```

Plugin setup without a prompt:

```bash
PEPONI_SETUP_MODE=local ./scripts/setup.sh
```

Checklist:

- [ ] Overlay with no credentials shows **Use locally (l)** and **Sign in (a)**
- [ ] `l` (or the local link) starts local mode without a terminal
- [ ] `n` then Enter adds a task; it is still there after `omarchy restart shell`
- [ ] Click the checkbox (or `j`/`k` then `Space`) to tick; unfinished stay at the top
- [ ] Click `↑`/`↓` (or `K`/`J`) to reorder within unfinished or within done
- [ ] `r` toggles rolling unfinished tasks onto today
- [ ] `↑` / `↓` then `Delete` removes the highlighted task
- [ ] Data file exists at `~/.local/share/peponi/store.json`

## 2. Rails API (peponi.to) — paid / cloud path

```bash
# from todo_app root, with a paid user in DB
bin/rails s

# login
curl -sS -X POST http://127.0.0.1:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"YOU@example.com","password":"YOUR_PASSWORD"}'

# use the returned token
TOKEN=...
curl -sS http://127.0.0.1:3000/api/v1/auth/status -H "Authorization: Bearer $TOKEN"
curl -sS http://127.0.0.1:3000/api/v1/days/$(date +%F) -H "Authorization: Bearer $TOKEN"
curl -sS http://127.0.0.1:3000/api/v1/not_yet -H "Authorization: Bearer $TOKEN"

# add / remove (Focus column)
curl -sS -X POST http://127.0.0.1:3000/api/v1/days/$(date +%F)/tasks \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Buy milk"}'
curl -sS -X DELETE http://127.0.0.1:3000/api/v1/todos/ID \
  -H "Authorization: Bearer $TOKEN"
```

Specs: `bundle exec rspec spec/requests/api/v1/desktop_helper_spec.rb`

## 3. CLI (cloud)

```bash
export PEPONI_BASE_URL=http://127.0.0.1:3000
export PATH="$PWD/bin:$HOME/.local/bin:$PATH"

peponi auth login
peponi day $(date +%F) --json
peponi add $(date +%F) "Buy milk"
peponi rm ID
peponi not-yet --json
```

## 4. Plugin

```bash
./scripts/install.sh
PEPONI_SETUP_MODE=local ./scripts/setup.sh
omarchy plugin validate ~/.config/omarchy/plugins/peponi.one-day
omarchy restart shell
omarchy-shell shell toggle peponi.one-day '{}'
```

Checklist:

- [ ] Signed-out overlay offers local **and** paid sign-in
- [ ] After `peponi auth local`, today’s list is editable with no website
- [ ] After `peponi auth login`, a snapshot is copied locally (`peponi auth status` shows `"mode":"local"`)
- [ ] `peponi pull` refreshes that copy
- [ ] `peponi auth login --cloud` keeps talking to peponi.to (only if you want live hosting)
- [ ] `n` opens composer; Enter adds a task
- [ ] Click checkbox or `Space` ticks; unfinished stay at the top
- [ ] Click `↑`/`↓` or `K`/`J` reorders
- [ ] `r` (or the roll-over line) toggles unfinished → today; paid pull copies `roll_over` from the API
- [ ] Local add does not appear on the website; `--cloud` add does
- [ ] `↑` / `↓` then `Delete` removes the highlighted task
- [ ] `←` / `→` change day and reload
- [ ] `y` opens Not Yet drawer
- [ ] With the drawer open, `n` adds a Not Yet task that stays after a shell restart
- [ ] `↑` / `↓` then `a` moves that task onto today (it leaves Not Yet)
- [ ] `↑` / `↓` then `Delete` removes a Not Yet task
- [ ] Bar `P` toggle works from chosen section (left/center/right)
- [ ] Optional `SUPER+ALT+O` toggles overlay

Cloud writes need the Rails add/remove routes **deployed** (`kamal deploy` in todo_app). Local mode is plugin-only.

## 5. Handoff

- No commit/new-repo from the agent — create the standalone repo yourself (see README).
- Keep Rails `/api/v1` on peponi.to; keep `peponi-omarchy/` as the helper package.
