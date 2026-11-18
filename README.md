# Fieldnotes

<img src="Assets/penguin.png" width="128" alt="Fieldnotes pixel penguin icon">

A local Mac planner with a white canvas, rounded type, and yellow and blue accents sampled from your references. Requires macOS 14 or later.

## Run on your Mac

1. Download or clone this repository and keep the whole folder together.
2. Double-click **Open Fieldnotes.command**, or run `zsh "Open Fieldnotes.command"` in Terminal.
3. If Apple command-line tools are missing, install them with `xcode-select --install`, then try again.

The launcher builds the app and opens `build/Fieldnotes.app`. You can copy that app to your Applications folder. The app is built for the Mac running the build (Apple Silicon or Intel); source builds support both.

The school import is optional: Fieldnotes works on its own with manually added tasks and arrangements.

## Planner

- The main window opens at **1040 × 780 (4:3)** and keeps that proportion when resized. On smaller screens it scales down to fit.
- The **Inbox** holds unplanned tasks; **All** includes scheduled tasks; **Done** holds completed tasks.
- Drag an inbox task into the calendar. Drag a calendar block to change its day or time, snapping to 15-minute steps. Calendar changes never change a school submission deadline.
- The blue line labeled **Now** marks the current Beijing time in today’s column.
- Use **Week / Day**, the date arrows, and **Today** to navigate. Double-click an empty time slot to add a task there, or use **Add task**. Click a block to edit exact start time, duration, and details.
- Completing a task shows a blue-and-yellow checkmark and confetti animation that dismisses automatically after about two seconds. Reduced Motion is respected.
- Overlapping entries appear in separate lanes. Overnight arrangements continue on the following day.

## Weekly arrangements and exceptions

Choose **Weekly arrangement**, then enter a title, weekday, start time, duration, first date, and optional final date. For example: Night study, every Tuesday, 17:00–20:00.

Click one occurrence in the calendar to **Save temporary change**, **Skip this date**, or **Restore regular**. A temporary change keeps a crossed-out original and adds the replacement. Dragging a recurring occurrence also changes only that occurrence. Future weeks continue normally, including when a one-off occurrence is moved into a different week.

Use **Edit weekly schedule** in an occurrence editor, or the pencil beside its name in the sidebar, to change the whole routine. Saved one-off overrides remain independent; deleting a series also removes its exceptions after confirmation.

## Desktop widget

**Today widget** toggles a separate **344 × 200** desktop card, matching the width of a medium Mac widget, with extra room for today’s arrangements. It lists today's arrangements with start and end times. Scroll for more entries, click one to edit it in the planner, or click **Open planner**. Drag the header to place it in a corner. Drag the blue grip in the bottom-right corner to resize it; its position and size are remembered.

The card lives at desktop level, behind ordinary app windows, and stays available while Fieldnotes runs even if the main planner is closed. The menu-bar calendar reopens the planner. This is an app-provided desktop card, not an Apple WidgetKit gallery extension. Quit Fieldnotes to close both the planner and the desktop card.

## School import and storage

**Import** reads the existing 作业速览 cache. Sync that app first. Reimporting refreshes titles, subjects, and deadlines, while preserving local planning, notes, effort, and completion. Imports start unplanned with a 30-minute estimate. Local completion does not submit schoolwork. Previously imported tasks are not removed automatically when school status changes.

Dates use Asia/Shanghai. Data stays in `~/Library/Application Support/Fieldnotes/planner.json`. Older planner files are loaded without losing tasks. No accounts, package downloads, or cloud service are required.

## Build and checks

Run `zsh build.command`. The build uses installed Apple command-line tools.

```sh
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path build/test-modules PlannerModel.swift ScheduleModel.swift ModelChecks.swift -o build/model-checks
build/model-checks
```

For isolated UI tests, set `FIELDNOTES_DATA_DIR` to a temporary directory when launching. Test arrangements never enter the real planner.

## Test and package

Run `zsh test.command` for model, persistence, recurring-exception, and completion-timeout checks. Run `python3 scripts/package_release.py` after building to create:

- `dist/Fieldnotes-GitHub.zip`: all Swift source, tests, scripts, documentation, and final icon assets.
- `dist/Fieldnotes-macOS.zip`: the built app for the current Mac architecture.

To upload through GitHub's website, unzip `Fieldnotes-GitHub.zip`, create a repository, and upload the **contents of the Fieldnotes folder**, including `Assets` and `scripts`. GitHub does not unpack a ZIP uploaded as a repository file. The app ZIP can be attached to a GitHub Release.

## What is stored where

- Repository: app source, tests, icon assets, and build scripts.
- `build/`: generated app and compiler caches; ignored by Git.
- `dist/`: release archives; ignored by Git.
- `~/Library/Application Support/Fieldnotes/planner.json`: personal tasks, recurring schedules, and exceptions; never included in release archives.
- The desktop-card visibility and position are stored in the app's local preferences.

The archive does not include school login details, personal tasks, temporary previews, compiler caches, or the separate 作业速览 source project. No repository license has been selected; add your preferred license before offering reuse permissions.
