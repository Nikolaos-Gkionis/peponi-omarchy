# Testing — Peponi Omarchy helper

## 1. Rails API (peponi.to)

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

## 2. CLI

```bash
export PEPONI_BASE_URL=http://127.0.0.1:3000
export PATH="$PWD/bin:$HOME/.local/bin:$PATH"

peponi auth login
peponi day $(date +%F) --json
peponi add $(date +%F) "Buy milk"
peponi rm ID
peponi not-yet --json
```

## 3. Plugin

```bash
./scripts/install.sh   # sign-in + pick bar section
omarchy plugin validate ~/.config/omarchy/plugins/peponi.one-day
omarchy restart shell
omarchy-shell shell toggle peponi.one-day '{}'
```

Checklist:

- [ ] Signed-out banner if credentials missing
- [ ] After login, today’s tasks appear
- [ ] `n` opens composer; Enter adds a task; it shows on the website Focus day
- [ ] `↑` / `↓` then `Delete` removes the highlighted task
- [ ] `←` / `→` change day and reload
- [ ] `y` opens Not Yet drawer with list tasks
- [ ] Bar `P` toggle works from chosen section (left/center/right)
- [ ] Optional `SUPER+ALT+O` toggles overlay

Writes need the Rails add/remove routes **deployed** (`kamal deploy` in todo_app). A plugin-only git push is not enough.

## 4. Handoff

- No commit/new-repo from the agent — create the standalone repo yourself (see README).
- Keep Rails `/api/v1` on peponi.to; keep `peponi-omarchy/` as the helper package.
