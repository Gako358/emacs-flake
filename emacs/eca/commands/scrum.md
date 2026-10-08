---
description: Refresh the daily scrum org note before standup, check standup notes against the boards after standup, or write the weekly performance review
---

Update the scrum org note. Run this in the `version` agent.

Arguments: `$ARGS`. It may contain a phase (`before`, `after` or `week`), an ISO week like `2026-W40` (only with `week`) and/or an org file path, in any order.
- Org file: the path in the arguments, otherwise `/home/merrinx/Documents/notes/20261006093858-scrum.org`.
- Phase: the word in the arguments. If none is given, use `after` when today's day heading exists with `:BEFORE_STANDUP:` set and at least one person has text under "Said:"; otherwise `before`. Never pick `week` unless it is given. Say which phase you ran in the reply.
- Week: the ISO week in the arguments, otherwise the current one (`date +%G-W%V`). Stop if it starts after today.

Sources:
- Epics: Kvalitetsregistre-OQR project 20, the standup board is view 20 "Prioritet" (https://github.com/orgs/Kvalitetsregistre-OQR/projects/20/views/20, filter `type:Epic no:parent-issue`). The fetch reads the whole project because Orphans needs the non-epic items too.
- Sub-issue status: Kvalitetsregistre-OQR project 24 "Backlog".
- NMKP: every NMKP item (`kvalreg-nmkp` issues and PRs) comes from HNIKT-Tjenesteutvikling-Systemutvikling project 90 (https://github.com/orgs/HNIKT-Tjenesteutvikling-Systemutvikling/projects/90). Never read a person's NMKP work from #20/#24; the NMKP#… epics there have no work tracking.
- Code repos: PRs and issues in the OQR6 code repos in HNIKT-Tjenesteutvikling-Systemutvikling (deformitet, kvalreg-*, oqr6; the list and the repo → register map are in the Handover). They show what people actually push. They are not a board: use them to cross-check the boards and the standup, never as a person's assigned work.
- People (week phase only): commits, PRs, reviews and issues of the Standup roster in all repos of both orgs (`Kvalitetsregistre-OQR`, `HNIKT-Tjenesteutvikling-Systemutvikling`), fetched by `/tmp/oqr-week.sh` (Handover). Repos owned by anyone else, such as personal repos, never count. Bot-authored PRs are not a person's work.

Rules:
- Read-only on GitHub. Do not create, edit, comment on, move or close anything. The org file is the only file you write.
- The `* Handover (session notes)` section is the source of truth for the data model, queries, orphan rules, daily routine, standup roster and migration order. Read the whole file before editing.
- Never reorder the NMKP migration queue and never change its "Why / when" column. Never edit the Standup roster.
- Keep the property drawer, `#+title`, `#+LINK` lines, section order, table columns (Issue link + About), and the `oqr:`, `nmkp:` and `hnikt:` link styles. Code items link as `[[hnikt:kvalreg-smerte/pull/448][kvalreg-smerte#448]]` (`/issues/` for issues).
- Text under a person's "Said:" (up to "Board:") is the user's standup notes. Never change, reformat, move or delete it, on any day.
- Keep any other text the user wrote by hand. If unsure whether a line is generated, keep it.
- If a fetch fails, say so under "Changes since previous day" and in your reply, and leave those numbers as UNVERIFIED. Never guess numbers.
- Idle threshold N: the "Idle threshold" line under `** Standup settings` in the Handover. Never edit it.
- Last activity: the newest `updatedAt` of the issue, its linked PRs and code PRs matched to it. For a #20 epic, the newest of the epic and its open sub-issues.
- Matching code to the boards, first hit wins: the PR's `closingIssuesReferences`; the code issue itself is on #20, #24 or #90; an issue number in the PR title or branch (`fix: 167 …`, `74-proms-…`) that is an issue in the repo's register (Handover map) or in the code repo itself; a clear title or release match. Otherwise the item is "not on the boards". HNIKT project 17 is not a standup board.
- Code bots (`dependabot`, `Copilot`, `copilot-swe-agent`) are counted per repo, never listed per person. A person's code items are PRs they authored or are assigned to, and code issues they opened or are assigned to.
- Since: the date of the newest day heading below today (yesterday if there is none).
- `* Weekly performance` is written only in the week phase, and only under the target week's heading. Before and after never touch it.
- Text under a person's "Notes:" in Weekly performance (up to the next heading) is the user's. Treat it like "Said:". Read it: it can say someone was away, part-time or on other work.
- Roles and people not to rate: the lines under `** Weekly review settings` in the Handover. Never edit them.

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
- Snapshot also has the rows "Planned items without assignee (Høy/KRITISK)" as `N (M)`, "Assigned work items idle N+ days", "Roster people with no activity in N+ days", "Code repos: open PRs (review required / approved / draft / bots)", "Code repos: PRs merged since previous day" and "Code work not on the boards (roster, since previous day)". When the previous day lacks a row, show it as new.
- Per person `Code:` table (in Standup notes, after "Board:"): `| PR/Issue | About | Repo | State | Board item | Days |` with the person's open PRs, PRs merged or closed since Since, and code issues they opened, were assigned or closed since Since. State is `open`, `draft`, `approved`, `changes req.`, `merged` or `closed`. Board item links the matched board issue with its board (`Smerte#167 (#24)`), or says `not on the boards` or `assigned to login` when someone else owns it. Last row `| code issues | N open assigned | | | | |` when they have older open assigned code issues. Write `Code: nothing since Since.` when empty.
- `* Code repos (HNIKT)`: refreshed like the other top-level sections. `** Open PRs` table `| PR | About | Author | State | Board item | Reviewed by | Days |` with every non-bot open PR, oldest last, then one line with bot PRs per repo. `** Since previous day`: PRs opened, merged and closed and code issues opened and closed, one line per repo with activity. `** Not on the boards`: open PRs and code items since Since by roster people that match no board item or an item someone else owns.

Weekly performance (week phase):
- `* Weekly performance` sits between `* Daily standup` and `* Action checklist`. One `** YYYY-Www (Mon D Mon – Sun D Mon)` per week, newest on top, with a property drawer `:WEEK_START:`, `:WEEK_END:`, `:DATA_UNTIL:` and `:GENERATED: [YYYY-MM-DD Day HH:MM]`. First line `Partial week: data up to Day D Mon.` when Data until is before WEEK_END, plus the standup days found. Then `*** Team summary` and one `*** login` per roster person, in roster order. Never sort or rank people.
- Facts, every number from the week fetch or the board fetch, never estimated:
  - Commits: unique commits with `parents` < 2 from `search/commits`, authored in the week, both orgs, per repo. Default branches only. Write the `contributionsCollection` count in brackets when it differs.
  - Commits on open PRs: commits the person authored in the week on their open PRs.
  - PRs opened / merged / closed: created, merged, or closed without merge in the week. PRs whose titles share the first three words, in 3+ repos on the same day, are one bulk change: `16 (11 bulk)`.
  - PRs open at week end: created by WEEK_END and not merged or closed by then, with drafts and the oldest age.
  - Lines merged: added and deleted lines of the person's PRs merged in the week, from the PR file lists, split into code / tests / docs. Generated, lock and vendored files are left out (patterns in the Handover's `oqr-week-lines.jq` block) and shown as "N generated left out". A bulk change counts once, at its largest PR. Wide changes (50+ files, under 15 lines per file) are shown apart as "N wide".
  - Merged PR sizes: each merged PR by its counted lines: XS ≤ 10, S ≤ 50, M ≤ 250, L ≤ 1000, XL > 1000, e.g. `2 L, 1 M, 2 S; bulk 11 × S`.
  - Lines in progress: lines of the person's own non-merge commits authored in the week on PRs still open, plus commits pushed without a PR, from the per-commit file lists, filtered and split like Lines merged. Add the number of commits, the days with commits and the PRs, drafts marked.
  - Reviews given: `pullRequestReviewContributions` in the two orgs on others' PRs, by state (approved, changes req., commented, dismissed), on how many PRs, and the counted lines and sizes of those PRs (a bulk change counts once).
  - Issues opened: `issueContributions` in the two orgs.
  - Assigned issues closed: `assignee:login closed:START..END`, with their board and status.
  - Assigned open (work status / Høy) and Idle assigned N+ days: as in the Board table and Idle assigned work, from this run's board fetch. Current week only; `n/a (past week)` otherwise.
  - Status moves: the person's moves named in the week's "Changes since previous day" and "Changed since before standup" lines.
  - Standup: day headings in the week, days with text under "Said:", and Check lines (`Matches` vs `Said, not on the board`, `Code, not on the board`, `On the board, not mentioned`). Empty "Said:" means no notes, not absence.
- `*** Team summary`: the line `D Delivery, C Collaboration, T Transparency, F Focus (1–5, n/a). Prev = Overall the week before.`, table `| Person | Role | Commits | PRs opened / merged | Lines merged / in progress | Reviews | Issues closed | Standup | D | C | T | F | Overall | Prev |` (lines as counted lines, wide and generated left out), then `Team:` with at most 5 lines of team-level facts (PRs merged, PRs waiting for review 3+ days, unassigned Høy/KRITISK work, deadlines in the week). No rankings.
- `*** login`: `Role:` from Weekly review settings; `Facts:` table `| Metric | Value |` with the rows Commits, Commits on open PRs, PRs opened / merged / closed, PRs open at week end, Lines merged, Merged PR sizes, Lines in progress, Reviews given, Issues opened, Assigned issues closed, Assigned open (work status / Høy), Idle assigned N+ days, Status moves, Standup, the same rows every week; `Evidence:` at most 6 lines linking the items behind the numbers, gaps included; `Review:` 2–4 lines; `Rating:` table `| Dimension | Score | Why |` with Delivery, Collaboration, Transparency, Focus and Overall; `Notes:` with `- ` (keep existing text). Links use the `oqr:`, `nmkp:` and `hnikt:` styles.
- Rating, 1–5 per dimension or n/a, against what the role expects that week:
  - 5 strong: clearly beyond the role's expectation, several facts. 4 good: what the role expects, minor gaps. 3 mixed: progress with notable gaps. 2 weak: little observable progress or repeated gaps. 1 concern: no observable progress on assigned work all week while present, or an at-risk deadline item with no activity.
  - Delivery: outcomes weighted by size, not by count: merged PRs (Lines merged, Merged PR sizes), assigned issues closed, items moved to For Test, Til test hos kunde or Klar for prodsetting, releases. One L or XL PR weighs as much as several S PRs; several XS PRs never outweigh one M. A bulk change counts once.
    Large work still in progress counts: Lines in progress of M size or more that match an assigned item or what the person said at standup are progress on a large issue, not a gap, also when pushed as one commit. Name the PR and the item; when there is no assigned item, that is a Transparency gap, not a Delivery gap.
  - Lines are context for size, never a score by themselves: deletions count like additions, tests and docs count, wide changes are judged by what they change, and lines are never compared between people. Large lines with no tests on risky code, or a large PR with no review, can be mentioned as a risk.
  - Collaboration: reviews of others' PRs weighted by the size of what was reviewed (one L review weighs more than several XS approvals) and how fast, handovers, answers to colleagues or customers seen in the week's notes.
  - Transparency: what was said and pushed maps to an assigned board item with a fitting status (Check lines, code not on the board, idle items, statuses the code contradicts).
  - Focus: progress on owned Høy/KRITISK items and deadlines within 14 days, and urgent unassigned work taken. n/a when they own none and took none.
  - Overall: mean of the rated dimensions, rounded to the nearest whole number with x.5 rounded down; n/a with fewer than 2 rated. Write `Rating (provisional):` in a partial week.
  - Every Why cites facts in the block (row names or linked items). Commit and line counts are never the only evidence. Never compare with other people, only with the role and the person's earlier weeks. Judge the work, not the person.
  - n/a when fewer than 2 facts support a dimension. Write `Not rated: reason` instead of the Rating table when the person is under "Not rated" in Weekly review settings, Notes say they were away half the week or more, or there is no GitHub activity and no standup notes in the week. Never score absence as 1.

Steps (all phases):
1. Run `date +%F`, `date +%A` and `date +%H:%M`. All "days over", "days left" and "days" values count from today.
2. Write the GraphQL queries and `/tmp/oqr-repos.sh` to `/tmp`:
   `emacs --batch --eval '(progn (require (quote org)) (org-babel-tangle-file "ORG_FILE"))'`
3. Fetch, read-only:
   - `gh__project_item_list` owner `Kvalitetsregistre-OQR`, number 20, limit 300, query `is:open -status:Avsluttet`
   - `gh api graphql --paginate -F query=@/tmp/oqr-subissues.graphql > /tmp/oqr-subissues.json`
   - `gh api graphql --paginate -F query=@/tmp/oqr-p24.graphql > /tmp/oqr-p24.json`
   - `gh api graphql --paginate -F query=@/tmp/oqr-p90.graphql > /tmp/oqr-p90.json`
   - `bash /tmp/oqr-repos.sh SINCE` with Since as `YYYY-MM-DD` (WEEK_START in the week phase). It writes `/tmp/oqr-repos-prs.json` (open PRs), `/tmp/oqr-repos-issues.json` (open issues) and `/tmp/oqr-repos-recent.json` (PRs and issues updated since Since).
   Read the paginated JSON with `jq -s`. Use the jq examples in the Handover.
4. Before editing, note the current contents of every section, including today's "Standup notes" if it exists. You need them for the comparisons below.

Before standup:
5. Daily standup:
   - If a heading for today already exists, update it in place. Otherwise insert `** YYYY-MM-DD Weekday` at the top of `* Daily standup`, above the previous day, with a property drawer holding `:BEFORE_STANDUP:` and an empty `:AFTER_STANDUP:`.
   - Set `:BEFORE_STANDUP:` to `[YYYY-MM-DD Day HH:MM]`.
   - Highlights: at most 7, most urgent first. Each ends with "→ who/what to ask". Include code work not on the boards when it is substantial (a feature PR, or work on another person's item).
   - Unassigned planned work and Idle assigned work: as defined under Day sections.
   - Snapshot: the same metric rows as the previous day, so the two can be compared.
   - Changes since previous day: compare with the previous day's snapshot and the section contents from step 4. Cover new and closed issues, status moves, items that passed their deadline, newly unassigned or assigned items, people who became idle or active again, PRs merged or still waiting (boards and code repos), code work not on the boards, and progress in the migration queue. Show numbers as `old → new`.
   - PO summary: as defined under Day sections, from the board data.
   - Standup notes: the intro line, `Follow-ups:` with "- Run =/scrum after= when the notes are written.", then one `**** login` per person in the Standup roster, in roster order, each with:
     - `Said:` followed by `- ` (keep existing text if the heading already exists).
     - `Board:` table `| Issue | About | Board | Status |` with what is assigned to the person: #20 epics they own (not Backlog/Parkert), open #24 sub-issues and loose issues, #90 issues outside Todo/Backlog plus #90 epics they own, and a last row `| #90 | N open in total | #90 | Todo/Backlog rest |` when they have #90 items. Mark Høy/KRITISK in Status and add "(shared)" in About when others are also assigned.
     - `Code:` table as defined under Day sections.
     - `Check:` followed by "- Not run yet."
   - On the previous days, drop the "Board:" and "Code:" tables and keep every other day section, Said and Check.
6. Refresh every other section in place with today's data, except `* Weekly performance`:
   - Rename `* Action checklist (DATE)` to today. Keep unchecked items that still apply. Drop checked or resolved items and list them under Changes as done.
   - Update deadlines, Til test hos kunde, Resources, Waiting on clarification, Merge questions, NMKP platform, Code repos, NMKP migration queue (only the "NMKP prep today" and "Current OQR6 work" columns), Board hygiene and Orphans.

After standup:
5. Today's heading must exist. If it doesn't, stop and tell the user to run `/scrum before` first.
   - Set `:AFTER_STANDUP:` to `[YYYY-MM-DD Day HH:MM]`.
   - Refresh Highlights, Unassigned planned work, Idle assigned work, Snapshot and "Changes since previous day" with the fresh data (still compared with the previous day).
   - Per person, compare the "Said:" text with the fresh data from all three boards (any status, not only the Board table), their code items, and the "Board:" and "Code:" tables from step 4. Match by issue number first, then by title, register or release. Then replace "Board:" and "Code:" with fresh tables and replace "Check:" with short lines, each linking the issue:
     - `Matches:` what was said and which assigned issue it is, with its current status and the code PR when there is one. Flag when the status doesn't fit what was said or the code (for example said "working on" while the item is Klar til utvikling, Todo or Mottatt; said "done" while it is open; a PR merged while the item is still Klar til utvikling), or when the item has had no activity for N+ days.
     - `Said, not on the board:` work with no matching issue, or an issue assigned to someone else or not assigned. Name the closest issue when there is one.
     - `On the board, not mentioned:` items in Utvikles, Under utvikling, In Progress, In Review or Need Work that were not mentioned.
     - `Code, not on the board:` the person's open PRs and code items since Since that match no board item, or match an item that is unassigned or assigned to someone else. Say whether it was mentioned.
     - `Changed since before standup:` status or assignee changes on the person's items between the before-standup Board table and now.
     - `- Nothing said.` when "Said:" is empty; still list the active items under "On the board, not mentioned".
     Omit empty categories.
   - Replace `Follow-ups:` with the board updates to ask for, one line each: issue, person, what to change (status, assignee, new issue, close). Include unassigned planned work someone said they would take. Nothing is written to GitHub.
   - Refresh the PO summary with the fresh data and the standup outcome: what was confirmed, new blockers, and decisions the team needs from the PO.
6. Refresh every other section in place exactly as in the before phase.

Week:
5. Dates: for `YYYY-Www`, `j=$(date -d "YYYY-01-04" +%u); start=$(date -d "YYYY-01-04 -$((j-1)) days +$((WW-1)) weeks" +%F); end=$(date -d "$start +6 days" +%F)`. Data until is today in the current week, otherwise WEEK_END.
   Run step 3 with Since = WEEK_START, then `bash /tmp/oqr-week.sh WEEK_START WEEK_END LOGIN...` with the logins from the Standup roster line, in roster order.
   It writes `/tmp/oqr-week/LOGIN-contrib.json`, `LOGIN-commits.jsonl`, `LOGIN-search.json` and `LOGIN-lines.jsonl` (per-file lines of commits outside merged PRs). Use the jq examples in the Handover; they read `/tmp/oqr-week-lines.jq` with `-L /tmp`.
6. Read the day headings dated in the week (Said, Check, Changes since previous day, the newest Idle assigned work), the previous week's heading for Prev, and Weekly review settings.
   - If the week's heading exists, update it in place: replace Team summary, Facts, Evidence, Review and Rating; keep Notes and any other text the user wrote. Otherwise insert it at the top of `* Weekly performance`. Set `:GENERATED:` and `:DATA_UNTIL:`.
   - Write the blocks as defined under Weekly performance. Never change another week or anything outside `* Weekly performance`.

All phases:
7. Only edit the Handover if the data model changed, for example a new status option or field. Then update "Data model (verified)".
8. Align all tables:
   `emacs --batch --eval '(progn (require (quote org)) (find-file "ORG_FILE") (setq org-link-descriptive t) (font-lock-ensure) (org-table-map-tables (lambda () (org-table-align)) t) (save-buffer))'`
9. Reply briefly with the phase, today's highlights, the people with no activity in N+ days and the main changes since yesterday. Also name code work not on the boards. After standup, also list the follow-ups and the people whose notes or code don't match the board, and say the PO summary is refreshed. Mention anything UNVERIFIED.
   In the week phase, reply with the week, Data until, the Team summary scores, who was not rated and why, and anything UNVERIFIED.
