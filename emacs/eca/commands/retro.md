---
description: Prepare the next retrospective from the scrum org note - what went well, what to improve, follow-up of the last retro's actions
---

Prepare talking points for the next retrospective. Run this in the `version` agent.

Arguments: `$ARGS`. It may contain a period `YYYY-MM-DD..YYYY-MM-DD`.
- Scrum note: `/home/merrinx/Documents/notes/20261006093858-scrum.org`. Read-only.
- Retro note: `/home/merrinx/Documents/notes/20261009181233-retro.org`. The only file you write.
- Period: the range in the arguments; otherwise from the day after the previous retro's `:PERIOD_END:` to today; otherwise from the oldest day heading under `* Daily standup` to today. Stop and say so if the period holds no day headings.

Sources, all from the two notes. Do not fetch GitHub: the retro reflects what the team saw and said at standup.
- Day headings `** YYYY-MM-DD Weekday` in the period: Highlights, Unassigned planned work, Idle assigned work, Snapshot, Changes since previous day, PO summary, and under Standup notes the Follow-ups and each person's Said and Check.
- `* Weekly performance` weeks that overlap the period: the `Team:` lines, and per person Facts, Evidence and Notes (only for "Not for the room").
- Current-state sections (Action checklist, Deadlines, Til test hos kunde, Merge, release and close questions, NMKP platform, Code repos, NMKP migration queue, Board hygiene, Orphans): they show the last run, not the period. Use them only for the end state.
- Handover: Standup roster, Standup settings (idle threshold N) and Known limitations.
- Retro note: `* Guide` (Formats and Agenda) and the previous retro under `* Retrospectives`, mainly its `*** Outcome`.

Rules:
- Never write to GitHub or the scrum note. In the retro note, write only under `* Retrospectives`; never edit `* Guide`, the property drawer, `#+title` or `#+LINK` lines.
- Text under a retro's `*** Outcome` (up to the next heading) is the user's. Never change, reformat, move or delete it, on any retro.
- Every talking point is backed by the scrum note: numbers as `first → last` with dates, and links to the issues behind them. Never estimate a number. If a row or section is missing on a day, say so.
- Patterns over events: a talking point needs the signal on 2+ days, a trend across the period, or one high-impact event (deadline met or missed, release, customer rejection, production bug).
- The room is about the system, not people. Plan, Since last retro, Period in numbers, Went well, To improve and Suggested experiments contain no GitHub logins, no per-person counts and nothing from the Weekly performance scores or ratings. Write "one developer owns four epics due within 13 days", not who.
  Exceptions: action owners the team agreed on in an earlier Outcome, and the `Shout-outs:` line, which names people only for a concrete contribution.
- Patterns about one person (no standup notes on most days, idle items, overload, board lagging their code, handovers that stall) go only under "Not for the room", for a 1:1. State facts and a supportive question; check their Notes and Said for absence or other work first. Never quote scores.
- Links use the `oqr:`, `nmkp:` and `hnikt:` styles of the scrum note, e.g. `[[oqr:Smerte/issues/173][Smerte#173]]`.

Signals to look for, both directions:
- Delivery: releases and epics closed or moved to Klar for prodsetting, deadlines met or missed, customer test confirmed or rejected, Høy/KRITISK deadlines in or just after the period.
- Flow: PRs waiting for review or approved but not merged across days, items idle N+ days, long waits in Til test hos kunde, Snapshot rows trending up or down.
- Ownership: Høy/KRITISK work without an assignee, epics without an owner or sub-issues close to the deadline, one person holding many deadlines, work moved by someone else instead of taken, handovers with no board change, unowned work someone took.
- Board vs reality: Check lines (`Matches` against `Said, not on the board`, `Code, not on the board`, `On the board, not mentioned`), PRs merged while the item is still Klar til utvikling, Todo or Backlog, work agreed at standup that never got an issue.
- Follow-through: Follow-ups and Action checklist items repeated as "still open from" across days, against those done the next day.
- Standup itself: days with empty Said, how often Check ran, and whether Highlights questions got answered.
- Hygiene: Orphans and Board hygiene counts, stale items closed.

Write, under `* Retrospectives`, newest on top. If a retro heading with today's date exists, update it in place and keep its Outcome; otherwise insert a new one:
- `** Retro YYYY-MM-DD (D Mon – D Mon)` with a property drawer `:PERIOD_START:`, `:PERIOD_END:`, `:SOURCE_DAYS:` (the day headings read, comma-separated) and `:GENERATED: [YYYY-MM-DD Day HH:MM]`.
  First line: how many standup days the period covers, how many have notes under Said, and how many have a Check run.
- `*** Plan`: `Format:` one from Guide → Formats not used in the previous two retros and suited to the period (for example Timeline after a release or a hard deadline, Sailboat when deadlines are at risk), with one line why.
  `Check-in:` one question tied to the period. `Timebox:` the Guide agenda with this retro's minutes adjusted if a stage needs more room.
- `*** Since last retro`: table `| Action | Owner | Evidence in period | State |` for each item under the previous retro's `Actions:`. State is `done`, `partly`, `not started` or `no data`; use the scrum note, not the checkbox, and say when they disagree. Write `First retro: no earlier actions.` when there is no previous retro.
- `*** Period in numbers`: table `| Metric | First day | Last day | Trend |` with 6–10 team-level Snapshot rows present on both the first and the last day of the period (planned Høy/KRITISK without assignee, active epics past deadline and without owner, idle items, PRs waiting for review, sub-issues in customer test, open issues under closed epics, and similar).
  Then `Timeline:` with at most 8 dated lines of key events (releases, deadlines, reorganisations, customer rejections, new production bugs).
- `*** Went well`: 3–6 numbered points, most valuable first. Each is `N. *Title* – observation`, then an indented `Evidence:` line, then an indented `→ question` that asks what made it work and how to keep it. End with `Shout-outs:` (concrete contributions, may name people) or leave it out.
- `*** To improve`: 3–6 numbered points, most impact first, same shape. The question asks for causes in how the team works, never for a culprit.
- `*** Suggested experiments`: at most 3, each tied to a To improve point by number: a small change for the next period, who would own it as a role, and the check in the scrum note that shows whether it worked (a Snapshot row, a Follow-ups line). These are prompts; the team decides.
- `*** Not for the room`: facilitator only, at most 5 lines, may name people. Write `Nothing.` when empty.
- `*** Outcome`: only when creating the retro, write `Discussion:` with `- ` and `Actions:` with `- [ ] action – owner – how we check`. Never touch it afterwards.

Steps:
1. Run `date +%F`, `date +%A` and `date +%H:%M`.
2. Read the whole retro note. Find the previous retro, its `:PERIOD_END:` and its Outcome.
3. In the scrum note, list headings with `eca__grep` (`^\*{1,3} `). Read every day heading in the period in full, the overlapping Weekly performance weeks, the current-state sections and the Handover settings. The note is large: read by section, but never skip a day in the period.
4. Write the retro as above.
5. Align all tables:
   `emacs --batch --eval '(progn (require (quote org)) (find-file "RETRO_FILE") (setq org-link-descriptive t) (font-lock-ensure) (org-table-map-tables (lambda () (org-table-align)) t) (save-buffer))'`
6. Reply briefly with the period and days covered, the format picked, the titles of Went well and To improve, the state of the previous actions, and anything missing or UNVERIFIED in the source.
