---
description: Plan today's training session, log what was done after it, and keep targets, deadlift progress and the weekly summary in the training org note up to date
---

Update the training org note.

Arguments: `$ARGS`. It may contain a phase (`plan`, `log`, `missed` or `week`), a date `YYYY-MM-DD`, an ISO week like `2026-W45` (only with `week`), an org file path and the sets done, in any order.
- Org file: the path in the arguments, otherwise `/home/merrinx/Documents/notes/20261031224707-training.org`.
- Date: the date in the arguments, otherwise today. A session done on another day than planned is logged on the date it was done, against the scheduled day it replaces (ask which when it is not clear).
- Phase: the word in the arguments. If none is given, use `log` when the arguments contain sets, otherwise `plan`. Say which phase you ran in the reply.
- Sets: free text per exercise, e.g. `deadlift 140x5 @8, 125x5x3; hack 100x10,9,8; laterals 12x15x4; bw 84; notes: left knee a bit sore`.
  - `140x5 @8` = 140 kg for 5 reps at RPE 8; `@r2` = RIR 2; `125x5x3` = 3 sets of 5 at 125 kg; `100x10,9,8` = three sets at 100 kg; `bw` alone = bodyweight; `+10x8` = bodyweight plus 10 kg.
  - `bw 84` sets Bodyweight in Settings. Text after `notes:` goes under the session's "Notes:".
  - Match exercise names to the keys in `* Current targets` (short names like `hack`, `rdl`, `laterals`, `ohp` are fine when only one key on the day fits). Ask with `eca__ask_user` when a name, load or rep count cannot be matched. Never guess a number.

Rules:
- The org file is the only file you write.
- `* Program` and `* Settings` are the plan. Never edit them, except `Bodyweight:` and `Deadlift start weight:` under Settings.
- Text under a session's "Notes:" (up to the next heading) is the user's. Never change, reformat, move or delete it, on any session. Append new notes from the arguments on new `- ` lines.
- The program never shifts. Program week = `floor((Date − :START:) / 7) + 1` from the `* Program` property drawer; the Schedule row gives the week type, the days and the deadlift scheme. Stop and say so when the date is before START or after the last week.
- Every load, rep and RPE comes from the arguments or the note. Effort not given is written as `–` and treated as the planned effort for progression, and the reply says so.
- e1RM, progression, deloads and new blocks follow `** Progression rules` exactly. Show e1RM rounded to 0.5 kg, loads rounded to the smallest step in Settings.
- Keep the property drawer, `#+title`, section order and table columns.

Log heading, under `* Log`, newest on top: `** YYYY-MM-DD Weekday – Day name (Wn)`, e.g. `** 2026-11-02 Monday – Lower A (W1)`, with a property drawer `:WEEK:`, `:DAY:` (the `*** ` day heading under `** Days`, e.g. `Mon – Lower A (deadlift)`), `:PLANNED:`, `:LOGGED:` and `:BODYWEIGHT:`. Then:
- table `| Exercise | Target | Done | Best set | e1RM | Next |`, one row per exercise of the day in program order:
  - Target: sets × reps @ effort and the load from Current targets (deload: the deload scheme). Deadlift: the top set and the back-off sets.
  - Done: the sets as given, e.g. `140×5 @8; 125×5×3`; `skipped` when not done; extra exercises get their own row with Target `–`.
  - Best set: the set with the highest e1RM. e1RM is filled for Deadlift, Overhead press, Hack squat and Pendulum squat; `–` for the rest.
  - Next: the next load and reps from the progression rules, or `same`, `+2.5 kg`, `−10%`.
- `Summary:` one line: exercises done of planned, sets done, best e1RM change for the e1RM lifts (`old → new`), stalls.
- `Notes:` with `- ` (keep existing text).

Plan:
1. Run `date +%F`, `date +%A` and `date +%H:%M`.
2. Read the whole note.
3. Find the program week and the scheduled day for Date. If Date is not a training day in that week, say so, name the next training day and its session, and stop.
4. If the heading exists, refresh Target only. Otherwise insert it with `:PLANNED:` set, empty `:LOGGED:`, Done, Best set, e1RM and Next empty, and `Notes:` with `- `.
5. Reply with the session as a short list: exercise, sets × reps @ effort, load, and for Deadlift the warm-up steps to the top set (bar, then ~40%, 60%, 75%, 85%, 95% of the top set, fewer reps each step).

Log:
1. Run `date +%F`, `date +%A` and `date +%H:%M`.
2. Read the whole note.
3. Find or create the heading for Date as in Plan step 4, then set `:LOGGED:` to `[YYYY-MM-DD Day HH:MM]` and `:BODYWEIGHT:` when given.
4. Fill Done, Best set, e1RM and Next, the Summary line and the Notes.
5. Update `* Current targets` for every exercise done: Next load (with reps when the rule changes them), Last done, Last date, and Stalls (sessions in a row below the rep range; 0 after a session in range). A deload week updates Last done and Last date only.
6. Deadlift done: add or update the week's row in `* Deadlift progress` (top set, RPE, e1RM, back-off, the next top set from the rules, a note on PRs or missed reps). In week 1 also set `Deadlift start weight:` in Settings.
7. If Date's session is the last training day of the program week, or a later session of that week is already logged, write the week's summary (Week below).
8. Align all tables:
   `emacs --batch --eval '(progn (require (quote org)) (find-file "ORG_FILE") (org-table-map-tables (lambda () (org-table-align)) t) (save-buffer))'`
9. Reply briefly: what was logged, new e1RMs and PRs, the next targets that changed, stalls, and anything entered as `–` or asked about.

Missed:
1. Do Plan steps 1–3. Insert or update the heading with `:LOGGED:` set, every Done as `missed` and Summary `Missed.`; keep Notes. Current targets do not change.
2. If it was a deadlift day, say in the reply that the Deadlift progress week has no row and the next week follows its Schedule row with the last top set.
3. Do Log steps 7–9.

Week:
1. Target week: the ISO week in the arguments, otherwise the current one (`date +%G-W%V`). It must be one of the Schedule rows.
2. Under `* Weekly summary`, newest on top, update in place or insert `** YYYY-Www – Week n (type, block)` with:
   - table `| Day | Date | Session | Done | Note |` with one row per scheduled day: logged date, `done`, `partly (n of m)`, `missed` or `not logged`;
   - `Volume:` hard sets per muscle group from the logged sessions (quads, hamstrings, glutes/back, chest, side delts, rear delts, front delts/pressing, back/lats, biceps, triceps, calves), deload sets included;
   - `Deadlift:` the week's top set, RPE, e1RM and the change from the previous week;
   - `PRs:` new best load × reps or e1RM per exercise this program; `Stalls:` exercises with Stalls ≥ 2;
   - `Next week:` the next Schedule row (type, days, deadlift scheme) and what changes, e.g. deload, new block, Friday added or dropped.
3. Align tables as in Log step 8 and reply with the summary in a few lines.
