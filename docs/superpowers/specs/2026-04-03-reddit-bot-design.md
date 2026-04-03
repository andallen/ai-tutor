# PaperClip Reddit Bot — Design Spec

**Date:** 2026-04-03
**Status:** Approved
**Project:** `paperclip-reddit-bot` (separate Python project, not part of the Swift app)

---

## Overview

A fully autonomous Reddit marketing bot for PaperClip. Runs as a single Python daemon on an Ubuntu Linux box (old gaming PC). Handles the entire lifecycle: account warmup, scheduled posting with native video upload, comment notification forwarding, organic engagement for ratio maintenance, and post monitoring.

**What the bot does:**
- Posts pre-written content to 29 subreddits on a schedule with native Reddit video
- Posts the first comment (with links) on each submission
- Detects new comments on posts and forwards them to Discord for manual reply
- Generates and posts organic comments in general-interest subs to maintain the 8:1 engagement ratio and build account history
- Monitors post performance (score, ratio, velocity) and alerts on anomalies

**What you do:**
- Record the demo video (once)
- Calibrate the AI persona by reviewing sample outputs (once)
- Proofread the 29 post bodies (once)
- Reply to comments from your phone via Discord notifications (ongoing)

---

## Architecture

Single long-running Python process using APScheduler for internal job scheduling. systemd manages the process lifecycle (auto-restart on crash). SQLite for all state. Discord webhooks for notifications.

### Components

| Component | Module | Frequency | Description |
|-----------|--------|-----------|-------------|
| **Poster** | `poster.py` | Every 5 min check | Checks `posts.json` for due posts. Uploads native video, submits post, posts first comment. |
| **Notifier** | `notifier.py` | Every 60 sec | Polls active posts for new comments. Forwards to Discord for manual reply. |
| **Organic Commenter** | `organic.py` | Every 3-5 hours (randomized jitter ±30 min) | Finds rising posts in curated subs. Generates helpful comments via Gemini. No PaperClip mentions. |
| **Monitor** | `monitor.py` | Every 2 min | Tracks post metrics. Alerts via Discord on removal, low ratio, or stall. |

### Support Modules

| Module | Purpose |
|--------|---------|
| `main.py` | Entry point. Loads config, initializes components, starts APScheduler. |
| `reddit_client.py` | PRAW wrapper. Auth, video upload, post submission, comment fetching. |
| `gemini_client.py` | Gemini API wrapper. Generates organic comments using persona config. |
| `discord_client.py` | Discord webhook wrapper. Sends alerts, post logs, comment notifications. |
| `db.py` | SQLite initialization, queries, state management. |

---

## Data Flow

### Loop 1 — Poster (every 5 min check)

```
Check posts.json for due posts
  → Upload video to Reddit media endpoint
  → Poll until video processing complete
  → Submit post (title, body, flair, video)
  → Post first comment with links
  → Mark as active in SQLite
  → Send Discord log
```

### Loop 2 — Notifier (every 60 sec)

```
For each active post in SQLite
  → Fetch comments via PRAW
  → Filter out already-seen and own comments
  → For each new comment:
    → Send to Discord with comment text, link to reply, post context
    → Mark as notified in SQLite
```

### Loop 3 — Organic Commenter (every 3-5 hours, randomized jitter ±30 min)

```
Pick a sub from curated list
  → Fetch rising posts
  → Filter for posts with 10-50 comments (active but not buried)
  → Read post + top comments
  → Generate helpful comment via Gemini (no PaperClip mention)
  → Submit via PRAW
  → Log in SQLite
```

### Loop 4 — Monitor (every 2 min)

```
For each active post
  → Fetch score, ratio, comment count
  → Calculate velocity
  → Log to SQLite
  → If removed: Discord alert
  → If ratio < 0.85: Discord alert
  → If 0 upvotes after 30 min: Discord alert (post stalled)
```

---

## Configuration

### config.yaml

```yaml
reddit:
  client_id: "..."
  client_secret: "..."
  username: "..."
  password: "..."
  user_agent: "paperclip-bot/1.0"

gemini:
  api_key: "..."
  model: "gemini-3-flash-preview"

discord:
  webhook_url: "https://discord.com/api/webhooks/..."
  channels:
    alerts: "..."        # post removals, stalls, errors
    post_log: "..."      # successful post submissions
    comments: "..."      # new comments forwarded for manual reply

persona:
  # Calibrated during tuning session before launch.
  # Bot generates sample comments, you review and adjust
  # until the voice sounds like you. Final persona saved here.
  config_file: "persona.json"

organic_subs:
  # Apple/tech
  - apple
  - ipad
  - swift
  - productivity
  - opensourcesoftware
  - linux
  # AI
  - ClaudeAI
  - ChatGPT
  - LocalLLaMA
  - MachineLearning
  - artificial
  # Add actual interests

posts_file: "posts.json"
db_path: "bot.db"
video_dir: "assets/"
```

### posts.json (one entry per subreddit)

```json
{
  "subreddit": "SideProject",
  "title": "I got tired of retyping what I'd already written by hand...",
  "body": "I write a lot by hand on my iPad...",
  "flair": null,
  "video_path": "assets/demo_v1.mp4",
  "first_comment": "Links: GitHub [link] | App Store [link]\n\nHappy to answer any questions!",
  "scheduled_at": "2026-04-15T09:00:00-04:00",
  "campaign_tag": "reddit_sideproject"
}
```

### persona.json (populated during tuning session)

```json
{
  "system_prompt": "You are commenting on Reddit as Andrew, a developer who built PaperClip...",
  "examples": [
    {
      "context": "r/apple thread about iPad accessories",
      "generated": "...",
      "approved": true
    }
  ]
}
```

---

## SQLite Schema

### posts

```sql
CREATE TABLE posts (
    id              INTEGER PRIMARY KEY,
    subreddit       TEXT NOT NULL,
    title           TEXT NOT NULL,
    scheduled_at    DATETIME NOT NULL,
    posted_at       DATETIME,
    reddit_id       TEXT,
    status          TEXT NOT NULL DEFAULT 'pending',  -- pending | posted | removed | failed
    score           INTEGER DEFAULT 0,
    upvote_ratio    REAL DEFAULT 0,
    comment_count   INTEGER DEFAULT 0,
    campaign_tag    TEXT
);
```

### comments

```sql
CREATE TABLE comments (
    id                  INTEGER PRIMARY KEY,
    post_id             INTEGER NOT NULL REFERENCES posts(id),
    reddit_comment_id   TEXT UNIQUE NOT NULL,
    author              TEXT NOT NULL,
    body                TEXT NOT NULL,
    notified_at         DATETIME,
    created_at          DATETIME NOT NULL
);
```

### organic_comments

```sql
CREATE TABLE organic_comments (
    id                  INTEGER PRIMARY KEY,
    subreddit           TEXT NOT NULL,
    reddit_comment_id   TEXT UNIQUE NOT NULL,
    reddit_post_id      TEXT NOT NULL,
    body                TEXT NOT NULL,
    created_at          DATETIME NOT NULL
);
```

---

## Project Structure

```
paperclip-reddit-bot/
├── config.yaml
├── posts.json
├── persona.json
├── assets/
│   ├── demo_v1.mp4
│   ├── demo_v2_ai.mp4
│   └── demo_v3_montage.mp4
├── bot/
│   ├── __init__.py
│   ├── main.py
│   ├── poster.py
│   ├── notifier.py
│   ├── organic.py
│   ├── monitor.py
│   ├── reddit_client.py
│   ├── gemini_client.py
│   ├── discord_client.py
│   └── db.py
├── requirements.txt
├── install.sh
└── paperclip-bot.service
```

---

## Error Handling

### Reddit API
- **Rate limited:** Exponential backoff, retry after delay
- **Auth expired:** Re-authenticate automatically
- **Video upload fails:** Retry twice, then skip post + Discord alert
- **Post submission fails:** Discord alert, mark as `failed` in SQLite, don't retry (avoid double-posting)

### Gemini API
- **Rate limited / down:** Skip organic comment this cycle, try next run
- **Nonsensical output:** Sanity check (length 10-500 chars, no obvious repetition), skip and retry if fails

### Post Removal
- Monitor checks if post is still accessible every 2 min
- If removed: mark as `removed` in SQLite, Discord alert, stop polling for comments on that post

### Duplicate Prevention
- SQLite tracks every `reddit_comment_id` — never notify twice
- SQLite tracks every post's `scheduled_at` — never double-post on restart
- Organic commenter checks SQLite — never comment on same post twice

### Process Crashes
- systemd `Restart=always` with 30-second delay
- On startup, bot reads SQLite to recover state
- APScheduler uses SQLite jobstore so scheduled jobs survive restarts

### Discord Webhook Failure
- If Discord is down, log locally to file. Never block main loops over a notification failure.

---

## Persona Tuning Workflow

Run once before launch to calibrate the AI's voice.

1. **Generate samples:** `python -m bot.tune` generates 20 sample organic comments across different subs via Gemini
2. **Review:** Samples print to terminal. For each, type `y` (good), `n` (bad), or type a correction
3. **Iterate:** Feedback appends to persona prompt as few-shot examples. Generate another batch. Repeat until satisfied.
4. **Save:** Final persona (system prompt + approved examples) saved to `persona.json`

---

## Dependencies

```
praw>=7.0
apscheduler>=3.10
google-genai
requests
pyyaml
```

---

## Deployment

- Runs on Ubuntu Linux box (old gaming PC, always on)
- Installed as a systemd service via `install.sh`
- `install.sh` creates a Python venv, installs deps, copies the systemd unit file, enables and starts the service
- Logs via systemd journal (`journalctl -u paperclip-bot -f`)

---

## What This Spec Does NOT Cover

- The 29 post bodies themselves (defined in APP_LAUNCH_PLAN.md sections 3A-3F)
- Video recording and editing
- Reddit account setup (already done)
- F5Bot keyword configuration (already defined in APP_LAUNCH_PLAN.md)
