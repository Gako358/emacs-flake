---
description: Refresh the daily scrum org note from GitHub projects 20, 24 and 90
---

Update the scrum org note for today's standup. Run this in the `version` agent.

Org file: `$ARGS`. If that is empty, use `/home/merrinx/Documents/notes/20261006093858-scrum.org`.

Rules:
- Read-only on GitHub. Do not create, edit, comment on, move or close anything. The org file is the only file you write.
- The `* Handover (session notes)` section is the source of truth for the data model, queries, orphan rules, daily routine and migration order. Read the whole file before editing.
- Never reorder the NMKP migration queue and never change its "Why / when" column.
- Keep the property drawer, `#+title`, `#+LINK` lines, section order, table columns (Issue link + About), and the `oqr:` and `nmkp:` link styles.
- Keep any text the user wrote by hand. If unsure whether a line is generated, keep it.
- If a fetch fails, say so under "Changes since previous day" and in your reply, and leave those numbers as UNVERIFIED. Never guess numbers.

Steps:
1. Run `date +%F` and `date +%A` for today and the weekday. All "days over", "days left" and "days" values count from today.
2. Write the GraphQL queries to `/tmp`:
   `emacs --batch --eval '(progn (require (quote org)) (org-babel-tangle-file "ORG_FILE"))'`
3. Fetch, read-only:
   - `gh__project_item_list` owner `Kvalitetsregistre-OQR`, number 20, limit 300, query `is:open -status:Avsluttet`
   - `gh api graphql --paginate -F query=@/tmp/oqr-subissues.graphql > /tmp/oqr-subissues.json`
   - `gh api graphql --paginate -F query=@/tmp/oqr-p24.graphql > /tmp/oqr-p24.json`
   - `gh api graphql --paginate -F query=@/tmp/oqr-p90.graphql > /tmp/oqr-p90.json`
   Read the paginated JSON with `jq -s`. Use the jq examples in the Handover.
4. Before editing, note the current contents of every section. You need them for the comparison in step 5.
5. Daily standup:
   - If a heading for today already exists, update it in place. Otherwise insert `** YYYY-MM-DD Weekday` at the top of `* Daily standup`, above the previous day.
   - Highlights: at most 7, most urgent first. Each ends with "→ who/what to ask".
   - Snapshot: the same metric rows as the previous day, so the two can be compared.
   - Changes since previous day: compare with the previous day's snapshot and the section contents from step 4. Cover new and closed issues, status moves, items that passed their deadline, newly unassigned or assigned items, PRs merged or still waiting, and progress in the migration queue. Show numbers as `old → new`.
   - Older days keep only Highlights, Snapshot and Changes.
6. Refresh every other section in place with today's data:
   - Rename `* Action checklist (DATE)` to today. Keep unchecked items that still apply. Drop checked or resolved items and list them under Changes as done.
   - Update deadlines, Til test hos kunde, Resources, Waiting on clarification, Merge questions, NMKP platform, NMKP migration queue (only the "NMKP prep today" and "Current OQR6 work" columns), Board hygiene and Orphans.
7. Only edit the Handover if the data model changed, for example a new status option or field. Then update "Data model (verified)".
8. Align all tables:
   `emacs --batch --eval '(progn (require (quote org)) (find-file "ORG_FILE") (setq org-link-descriptive t) (font-lock-ensure) (org-table-map-tables (lambda () (org-table-align)) t) (save-buffer))'`
9. Reply briefly with today's highlights, the main changes since yesterday, and anything that is UNVERIFIED.
