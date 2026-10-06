---
description: Refresh the daily scrum org note before standup, or check standup notes against the boards after standup
---

Update the scrum org note. Run this in the `version` agent.

Arguments: `$ARGS`. It may contain a phase (`before` or `after`) and/or an org file path, in any order.
- Org file: the path in the arguments, otherwise `/home/merrinx/Documents/notes/20261006093858-scrum.org`.
- Phase: the word in the arguments. If none is given, use `after` when today's day heading exists with `:BEFORE_STANDUP:` set and at least one person has text under "Said:"; otherwise `before`. Say which phase you ran in the reply.

Sources:
- Epics: Kvalitetsregistre-OQR project 20, the standup board is view 20 "Prioritet" (https://github.com/orgs/Kvalitetsregistre-OQR/projects/20/views/20, filter `type:Epic no:parent-issue`). The fetch reads the whole project because Orphans needs the non-epic items too.
- Sub-issue status: Kvalitetsregistre-OQR project 24 "Backlog".
- NMKP: every NMKP item (`kvalreg-nmkp` issues and PRs) comes from HNIKT-Tjenesteutvikling-Systemutvikling project 90 (https://github.com/orgs/HNIKT-Tjenesteutvikling-Systemutvikling/projects/90). Never read a person's NMKP work from #20/#24; the NMKP#… epics there have no work tracking.

Rules:
- Read-only on GitHub. Do not create, edit, comment on, move or close anything. The org file is the only file you write.
- The `* Handover (session notes)` section is the source of truth for the data model, queries, orphan rules, daily routine, standup roster and migration order. Read the whole file before editing.
- Never reorder the NMKP migration queue and never change its "Why / when" column. Never edit the Standup roster.
- Keep the property drawer, `#+title`, `#+LINK` lines, section order, table columns (Issue link + About), and the `oqr:` and `nmkp:` link styles.
- Text under a person's "Said:" (up to "Board:") is the user's standup notes. Never change, reformat, move or delete it, on any day.
- Keep any other text the user wrote by hand. If unsure whether a line is generated, keep it.
- If a fetch fails, say so under "Changes since previous day" and in your reply, and leave those numbers as UNVERIFIED. Never guess numbers.
- Idle threshold N: the "Idle threshold" line under `** Standup settings` in the Handover. Never edit it.
- Last activity: the newest `updatedAt` of the issue and its linked PRs. For a #20 epic, the newest of the epic and its open sub-issues.

Day sections, written under today's heading in this order: Highlights, Unassigned planned work, Idle assigned work, Snapshot, Changes since previous day, PO summary, Standup notes.
- `*** Unassigned planned work – who takes it?`: table `| Issue | About | Release | Prio | Deadline | Status |` with
  - #20 epics in Klar for prodsetting, Testing, Utvikles, Prioritert neste, Neste or 3. part without an owner;
  - open sub-issues of those epics without an assignee (any status except Parkert), and #24 issues without an epic in Klar til utvikling or Under utvikling without an assignee;
  - #90 items without an assignee in In Progress, In Review, Need Work or For Test, and one row per open #90 epic that has unassigned open children ("N of M open unassigned");
  - one row per register for unassigned #90 Todo/Backlog items whose register has a release on #20 (Soreg, PHV, BUP).
  Put an epic and its unassigned sub-issues in one row, and 3+ sibling sub-issues as a range (`NMKP#4–#10`). Order: KRITISK, Høy, then earliest deadline (none last), then in-work statuses before planned ones. At most 15 rows, then one line naming the rest and pointing to Resources.
- `*** Idle assigned work – no activity in N+ days`: first the line `No activity in N+ days on anything assigned: logins` (or `Everyone in the roster has recent activity.`) and `Nothing assigned: logins` when someone has no open assigned items. Both lines use every open assigned item on all three boards, any status. Then table `| Person | Issue | About | Status | Last activity | Days |` with roster people's items idle for N+ days in work statuses: #20 epics they own in Utvikles, Testing or Klar for prodsetting; #24 Klar til utvikling or Under utvikling; #90 In Progress, In Review, Need Work or For Test. Roster order, oldest first, Person only on a person's first row, at most 5 rows per person plus "N more".
- `*** PO summary`: for the product owner, who does not read the boards. Written in Norwegian (bokmål), unlike the rest of the note. One `#+begin_example` block, plain text ready to paste: no org links or markup, no GitHub logins, release and register names first with issue numbers like `Smerte#173` only in parentheses. At most 15 lines:
  `Status YYYY-MM-DD:` one line; `Frister` (Høy/KRITISK and the next 14 days: i rute, i fare or forsinket, and why); `Ferdig siden i går`; `Venter på kunde`; `Risiko` (unassigned and idle work that threatens a deadline); `Beslutninger vi trenger` (scope, priority, release with or without open bugs, planning questions); one `NMKP-migrering:` line. Omit empty parts.
- Snapshot also has the rows "Planned items without assignee (Høy/KRITISK)" as `N (M)`, "Assigned work items idle N+ days" and "Roster people with no activity in N+ days". When the previous day lacks a row, show it as new.

Steps (both phases):
1. Run `date +%F`, `date +%A` and `date +%H:%M`. All "days over", "days left" and "days" values count from today.
2. Write the GraphQL queries to `/tmp`:
   `emacs --batch --eval '(progn (require (quote org)) (org-babel-tangle-file "ORG_FILE"))'`
3. Fetch, read-only:
   - `gh__project_item_list` owner `Kvalitetsregistre-OQR`, number 20, limit 300, query `is:open -status:Avsluttet`
   - `gh api graphql --paginate -F query=@/tmp/oqr-subissues.graphql > /tmp/oqr-subissues.json`
   - `gh api graphql --paginate -F query=@/tmp/oqr-p24.graphql > /tmp/oqr-p24.json`
   - `gh api graphql --paginate -F query=@/tmp/oqr-p90.graphql > /tmp/oqr-p90.json`
   Read the paginated JSON with `jq -s`. Use the jq examples in the Handover.
4. Before editing, note the current contents of every section, including today's "Standup notes" if it exists. You need them for the comparisons below.

Before standup:
5. Daily standup:
   - If a heading for today already exists, update it in place. Otherwise insert `** YYYY-MM-DD Weekday` at the top of `* Daily standup`, above the previous day, with a property drawer holding `:BEFORE_STANDUP:` and an empty `:AFTER_STANDUP:`.
   - Set `:BEFORE_STANDUP:` to `[YYYY-MM-DD Day HH:MM]`.
   - Highlights: at most 7, most urgent first. Each ends with "→ who/what to ask".
   - Unassigned planned work and Idle assigned work: as defined under Day sections.
   - Snapshot: the same metric rows as the previous day, so the two can be compared.
   - Changes since previous day: compare with the previous day's snapshot and the section contents from step 4. Cover new and closed issues, status moves, items that passed their deadline, newly unassigned or assigned items, people who became idle or active again, PRs merged or still waiting, and progress in the migration queue. Show numbers as `old → new`.
   - PO summary: as defined under Day sections, from the board data.
   - Standup notes: the intro line, `Follow-ups:` with "- Run =/scrum after= when the notes are written.", then one `**** login` per person in the Standup roster, in roster order, each with:
     - `Said:` followed by `- ` (keep existing text if the heading already exists).
     - `Board:` table `| Issue | About | Board | Status |` with what is assigned to the person: #20 epics they own (not Backlog/Parkert), open #24 sub-issues and loose issues, #90 issues outside Todo/Backlog plus #90 epics they own, and a last row `| #90 | N open in total | #90 | Todo/Backlog rest |` when they have #90 items. Mark Høy/KRITISK in Status and add "(shared)" in About when others are also assigned.
     - `Check:` followed by "- Not run yet."
   - On the previous days, drop the "Board:" tables and keep every other day section, Said and Check.
6. Refresh every other section in place with today's data:
   - Rename `* Action checklist (DATE)` to today. Keep unchecked items that still apply. Drop checked or resolved items and list them under Changes as done.
   - Update deadlines, Til test hos kunde, Resources, Waiting on clarification, Merge questions, NMKP platform, NMKP migration queue (only the "NMKP prep today" and "Current OQR6 work" columns), Board hygiene and Orphans.

After standup:
5. Today's heading must exist. If it doesn't, stop and tell the user to run `/scrum before` first.
   - Set `:AFTER_STANDUP:` to `[YYYY-MM-DD Day HH:MM]`.
   - Refresh Highlights, Unassigned planned work, Idle assigned work, Snapshot and "Changes since previous day" with the fresh data (still compared with the previous day).
   - Per person, compare the "Said:" text with the fresh data from all three boards (any status, not only the Board table) and with the "Board:" table from step 4. Match by issue number first, then by title, register or release. Then replace "Board:" with the fresh table and replace "Check:" with short lines, each linking the issue:
     - `Matches:` what was said and which assigned issue it is, with its current status. Flag when the status doesn't fit what was said (for example said "working on" while the item is Klar til utvikling, Todo or Mottatt; said "done" while it is open), or when the item has had no activity for N+ days.
     - `Said, not on the board:` work with no matching issue, or an issue assigned to someone else or not assigned. Name the closest issue when there is one.
     - `On the board, not mentioned:` items in Utvikles, Under utvikling, In Progress, In Review or Need Work that were not mentioned.
     - `Changed since before standup:` status or assignee changes on the person's items between the before-standup Board table and now.
     - `- Nothing said.` when "Said:" is empty; still list the active items under "On the board, not mentioned".
     Omit empty categories.
   - Replace `Follow-ups:` with the board updates to ask for, one line each: issue, person, what to change (status, assignee, new issue, close). Include unassigned planned work someone said they would take. Nothing is written to GitHub.
   - Refresh the PO summary with the fresh data and the standup outcome: what was confirmed, new blockers, and decisions the team needs from the PO.
6. Refresh every other section in place exactly as in the before phase.

Both phases:
7. Only edit the Handover if the data model changed, for example a new status option or field. Then update "Data model (verified)".
8. Align all tables:
   `emacs --batch --eval '(progn (require (quote org)) (find-file "ORG_FILE") (setq org-link-descriptive t) (font-lock-ensure) (org-table-map-tables (lambda () (org-table-align)) t) (save-buffer))'`
9. Reply briefly with the phase, today's highlights, the people with no activity in N+ days and the main changes since yesterday. After standup, also list the follow-ups and the people whose notes don't match the board, and say the PO summary is refreshed. Mention anything UNVERIFIED.
