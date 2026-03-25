# n8n Job Search Agent 🤖

An automated job search, processing, and application tracking system built for n8n. Discovers jobs, processes JDs with AI, tailors resumes, and keeps you on top of every application — all on autopilot.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      JOB SEARCH AGENT                           │
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌────────────────┐  │
│  │ 01-Discovery │────▶│ 02-JD Proc.  │────▶│ 03-Resume Opt. │  │
│  │  (6h cron)   │     │  (webhook)   │     │   (webhook)    │  │
│  └──────────────┘     └──────────────┘     └────────────────┘  │
│                              │                      │           │
│                              ▼                      ▼           │
│  ┌──────────────┐     ┌──────────────┐     ┌────────────────┐  │
│  │ 06-Email Mon │────▶│ 04-App Track │     │   PostgreSQL   │  │
│  │  (30m cron)  │     │  (webhook)   │     │   Database     │  │
│  └──────────────┘     └──────────────┘     └────────────────┘  │
│                                                     │           │
│  ┌──────────────┐                                   ▼           │
│  │ 05-Daily Sum │◀──────────────────────────────────┘           │
│  │  (9am cron)  │                                               │
│  └──────────────┘                                               │
│         │                                                       │
│         ▼                                                       │
│    Telegram Bot 📱                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **n8n** (self-hosted) | v1.30+ recommended. Docker install covered in `install.sh` |
| **PostgreSQL 15+** | Included in Docker Compose setup |
| **RapidAPI JSearch** | Free tier: 200 req/month. [Subscribe here](https://rapidapi.com/letscrape-6bRBa3QguO5/api/jsearch) |
| **OpenAI API** | GPT-4o-mini used for cost efficiency |
| **Telegram Bot** | Create via [@BotFather](https://t.me/botfather) |
| **Gmail OAuth2** | For email monitoring (workflow 06) |

---

## Quick Start

```bash
# 1. Clone / copy this project
cd /home/ubuntu && git clone <your-repo> n8n-job-agent
cd n8n-job-agent

# 2. Copy and configure environment
cp setup/.env.example setup/.env
nano setup/.env   # Fill in your API keys

# 3. Run install script
chmod +x setup/install.sh
./setup/install.sh

# 4. Open n8n
open http://localhost:5678

# 5. Import workflows (in order)
# n8n UI → Workflows → Import → select each JSON from workflows/

# 6. Configure credentials in n8n
#    - PostgreSQL connection
#    - RapidAPI header credential
#    - OpenAI API key
#    - Telegram Bot Token

# 7. Add your base resume
mkdir -p /home/ubuntu/resumes/tailored
cp your_resume.txt /home/ubuntu/resumes/base_resume.txt

# 8. Activate workflows
# 01, 05, 06 are cron-based → activate in n8n UI
# 02, 03, 04 are webhook-based → activate to expose endpoints
```

---

## Workflow Descriptions

### 01 - Job Discovery (Cron: every 6 hours)

Searches JSearch API for jobs in India matching your target roles, deduplicates against the database, and triggers JD processing for each new job.

```
Schedule Trigger (0 */6 * * *)
    │
    ▼
Set Keywords ["Software Engineer", "SRE", "Backend Developer", ...]
    │
    ▼
SplitInBatches (per keyword)
    │
    ▼
HTTP Request → JSearch API (3 pages, last week)
    │
    ▼
Code Node (parse + transform jobs)
    │
    ▼
SplitInBatches (per job)
    │
    ▼
Postgres: Check Duplicate
    │
    ├── EXISTS → skip
    │
    └── NEW ──▶ Postgres: INSERT job_postings
                    │
                    ▼
               HTTP POST → /webhook/process-jd
                    │
                    ▼
               Postgres: Log to system_log
```

### 02 - JD Processor (Webhook: POST /webhook/process-jd)

Fetches the raw JD from DB, sends to GPT-4o-mini for structured extraction, calculates skill match score against Kartik's profile, stores in `processed_jobs`, and sends Telegram alert for high-match jobs.

```
Webhook POST /webhook/process-jd {job_id}
    │
    ▼
Postgres: SELECT job_postings WHERE id = job_id
    │
    ▼
HTTP Request → OpenAI (jd-processor prompt)
    │
    ▼
Code: Parse JSON + Calculate Skill Match Score
    │
    ▼
Postgres: INSERT processed_jobs
    │
    ▼
Postgres: UPDATE job_postings SET is_processed=true
    │
    ├── score < 70 → Log only
    │
    └── score ≥ 70 ──▶ Telegram Alert 🎯
                          │
                          ▼
                     Postgres: Log
                          │
                          ▼
                     Respond {success: true}
```

### 03 - Resume Optimizer (Webhook: POST /webhook/optimize-resume)

Tailors your base resume for a specific job using AI, saves the output, and creates an application tracker entry.

```
Webhook POST /webhook/optimize-resume {job_id}
    │
    ▼
Postgres: SELECT job + processed_job data
    │
    ▼
Read File: /home/ubuntu/resumes/base_resume.txt
    │
    ▼
HTTP Request → OpenAI (resume-optimizer prompt)
    │
    ▼
Code: Parse response, generate filename
    │
    ▼
Write File: /home/ubuntu/resumes/tailored/resume_{company}_{role}.txt
    │
    ▼
Postgres: INSERT resume_versions
    │
    ▼
Postgres: INSERT applications_tracker (status: Not Applied)
    │
    ▼
Telegram: Resume ready notification
    │
    ▼
Postgres: Log → Respond {success: true}
```

### 04 - Application Tracker (Webhook + Cron)

**Webhook flow:** Updates application status in DB and sends alerts for Offers/Rejections.
**Cron flow (hourly):** Checks for stale applications not followed up in 7+ days.

```
[A] Webhook POST /webhook/update-application
    │
    ▼
Code: Validate status enum
    │
    ▼
Postgres: UPDATE applications_tracker
    │
    ├── Applied → SET applied_at = NOW()
    ├── Offer → Telegram 🎉
    └── Rejected → Telegram 😔

[B] Schedule Trigger (every hour)
    │
    ▼
Postgres: SELECT stale applied applications (>7 days)
    │
    ▼
Code: Format stale list
    │
    └── count > 0 ──▶ Telegram reminder
```

### 05 - Daily Summary (Cron: 9:00 AM daily)

Pulls stats from all tables, formats a crisp daily digest via OpenAI, and sends to Telegram.

```
Schedule Trigger (0 9 * * *)
    │
    ▼
Postgres: Count new jobs (last 24h)
    │
    ▼
Postgres: Count new applications (last 24h)
    │
    ▼
Postgres: Top 5 high-match unapplied jobs (score ≥ 70)
    │
    ▼
Postgres: Applications grouped by status
    │
    ▼
Code: Compile summary object
    │
    ▼
HTTP → OpenAI: Format as daily digest
    │
    ▼
HTTP → Telegram: Send digest
    │
    ▼
Postgres: Log
```

### 06 - Email Monitor (Cron: every 30 minutes)

Monitors Gmail for job-related emails, classifies them with AI, auto-updates application status, and alerts you on anything requiring action.

```
Schedule Trigger (*/30 * * * *)
    │
    ▼
HTTP → Gmail API: List unread messages
    │
    ▼
Code: Filter job-related emails (interview/offer/rejected/...)
    │
    ├── none → done
    │
    └── found ──▶ SplitInBatches (per email)
                      │
                      ▼
                 HTTP → OpenAI: Classify email + suggest status
                      │
                      ▼
                 Code: Parse classification
                      │
                      ├── match found → POST /webhook/update-application
                      │
                      └── action required → Telegram alert
                                │
                                ▼
                           Postgres: Log
```

---

## Database Schema

| Table | Purpose |
|---|---|
| `job_postings` | Raw scraped jobs from JSearch |
| `processed_jobs` | AI-extracted JD analysis + match score |
| `resume_versions` | Tailored resumes per job |
| `applications_tracker` | Status tracking per application |
| `user_style_memory` | Learning from resume edits (future use) |
| `system_log` | Audit log for all workflow actions |

---

## API Keys Required

| Service | Where to Get | Used In |
|---|---|---|
| **RapidAPI (JSearch)** | rapidapi.com/jsearch | Workflow 01 |
| **OpenAI** | platform.openai.com | Workflows 02, 03, 05, 06 |
| **Telegram Bot Token** | @BotFather on Telegram | Workflows 02–06 |
| **Telegram Chat ID** | @userinfobot or getUpdates | Workflows 02–06 |
| **Gmail OAuth2** | Google Cloud Console | Workflow 06 |

---

## Setting Up Your Base Resume

Your base resume is the source of truth. The AI will only reframe — never fabricate.

1. Create a plain text resume at `/home/ubuntu/resumes/base_resume.txt`
2. Structure it clearly:
   ```
   KARTIK ANAND
   kartikanand0012@gmail.com | LinkedIn | GitHub

   SUMMARY
   ...

   SKILLS
   React, TypeScript, Python, Django, Node.js, GoLang, AWS, ...

   EXPERIENCE
   Ness Engineering (Vendavo) | Full-Stack Developer | 2023–Present
   - Built...

   IIT Bombay | PG Diploma in Machine Learning | 2024

   EDUCATION
   ...
   ```
3. The more detail you provide, the better the tailoring.

---

## Telegram Setup

1. Message [@BotFather](https://t.me/botfather): `/newbot`
2. Copy the bot token → `TELEGRAM_BOT_TOKEN` in `.env`
3. Start a chat with your bot
4. Get your chat ID:
   ```bash
   curl "https://api.telegram.org/bot<TOKEN>/getUpdates"
   # Look for "id" in the "chat" object
   ```
5. Set `TELEGRAM_CHAT_ID` in `.env`

---

## Triggering Resume Optimization Manually

Once a high-match job is discovered and processed, trigger resume optimization:

```bash
curl -X POST http://localhost:5678/webhook/optimize-resume \
  -H "Content-Type: application/json" \
  -d '{"job_id": 42}'
```

---

## Updating Application Status

```bash
curl -X POST http://localhost:5678/webhook/update-application \
  -H "Content-Type: application/json" \
  -d '{
    "job_id": 42,
    "status": "Interview Round 1",
    "notes": "Technical interview scheduled for Friday",
    "next_action": "Prep DSA + system design"
  }'
```

Valid statuses: `Not Applied`, `Applied`, `HR Screening`, `Interview Round 1`, `Interview Round 2`, `Technical Round`, `Offer`, `Rejected`, `Withdrawn`

---

## Troubleshooting

### n8n not starting
```bash
docker-compose logs n8n
# Check port 5678 is free: lsof -i :5678
```

### PostgreSQL connection failed
```bash
docker-compose exec postgres psql -U n8n_user -d job_agent -c "\dt"
# Verify credentials match .env
```

### JSearch returning empty results
- Check RapidAPI key is active (free tier has monthly limits)
- Verify `X-RapidAPI-Host: jsearch.p.rapidapi.com` header is set
- Try query manually: `curl "https://jsearch.p.rapidapi.com/search?query=Software+Engineer+India&num_pages=1"`

### Telegram messages not arriving
```bash
curl "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=<CHAT_ID>&text=test"
```

### Webhook not reachable
- Workflows 02, 03, 04 must be **Activated** in n8n UI
- If n8n is behind a reverse proxy, set `WEBHOOK_URL` to your public URL
- Test: `curl -X POST http://localhost:5678/webhook/process-jd -H "Content-Type: application/json" -d '{"job_id":1}'`

### Resume file not found
- Ensure `/home/ubuntu/resumes/base_resume.txt` exists
- Check file permissions: `chmod 644 /home/ubuntu/resumes/base_resume.txt`
- n8n Docker needs volume mount — check `docker-compose.yml`

---

## Cost Estimate (Monthly)

| Service | Cost |
|---|---|
| RapidAPI JSearch (free tier) | $0 (200 req) |
| OpenAI GPT-4o-mini | ~$2–5 (depends on volume) |
| n8n (self-hosted) | $0 |
| PostgreSQL (self-hosted) | $0 |
| Telegram | $0 |

---

## File Structure

```
n8n-job-agent/
├── README.md                    ← This file
├── setup/
│   ├── schema.sql               ← PostgreSQL schema
│   ├── .env.example             ← Environment template
│   └── install.sh               ← One-shot Docker setup
├── workflows/
│   ├── 01-job-discovery.json    ← Import into n8n
│   ├── 02-jd-processor.json
│   ├── 03-resume-optimizer.json
│   ├── 04-application-tracker.json
│   ├── 05-daily-summary.json
│   └── 06-email-monitor.json
└── prompts/
    ├── jd-processor.md          ← LLM prompts (reference)
    ├── resume-optimizer.md
    └── match-scorer.md
```
