# 🤖 n8n Job Search Agent — Complete Setup Guide

> **Who is this for?** Complete beginners. No prior experience with n8n, Docker, databases, or APIs needed. Every step is explained from scratch.

---

## Table of Contents

1. [What This Does](#1-what-this-does)
2. [What You'll Need](#2-what-youll-need)
3. [Part 1: Install Docker](#part-1-install-docker)
4. [Part 2: Get Your API Keys](#part-2-get-your-api-keys)
5. [Part 3: Set Up the Project](#part-3-set-up-the-project)
6. [Part 4: Import Workflows into n8n](#part-4-import-workflows-into-n8n)
7. [Part 5: Configure Credentials in n8n](#part-5-configure-credentials-in-n8n)
8. [Part 6: Set Up Your Base Resume](#part-6-set-up-your-base-resume)
9. [Part 7: Activate and Test](#part-7-activate-and-test)
10. [Part 8: Daily Usage](#part-8-daily-usage)
11. [Troubleshooting](#troubleshooting)
12. [FAQ](#faq)

---

## 1. What This Does

In plain English: **this is a robot that hunts jobs for you, tailors your resume automatically, and tracks your applications — all without you lifting a finger.**

Here's exactly what happens:

- **Every 6 hours** → searches job boards (JSearch API) for Software Engineer / Backend / Full Stack / SRE roles in India
- **Each job gets an AI score (0–100%)** → how well it matches your skills
- **Only notifies you (via Telegram)** when the match score is ≥ 70% — no spam
- **Automatically tailors your resume** for each high-match job using OpenAI
- **Tracks all your applications** in one database (Applied → HR Screening → Interview → Offer/Rejected)
- **Reads your Gmail every 30 minutes** → if an interview invite or rejection email arrives, it auto-updates your tracker
- **Every morning at 9 AM** → sends you a clean daily digest on Telegram with new jobs + your full application pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HOW IT ALL WORKS                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Job Boards ──► [Scrape every 6h] ──► [AI scores match]             │
│                                              │                        │
│                                         ≥ 70%? ──► Telegram alert   │
│                                              │                        │
│                                         Resume tailored ──► Saved   │
│                                                                       │
│  Your Gmail ──► [Check every 30min] ──► [AI classifies email]       │
│                       │                        │                      │
│                       └────────────────► Tracker auto-updated       │
│                                                                       │
│  Every 9 AM ──► Daily digest ──► Telegram                           │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

**The result:** You wake up, check Telegram, see exactly which jobs are worth applying to, find your tailored resume already saved, and know the status of every application.

---

## 2. What You'll Need

| Item | Cost | Time to set up |
|------|------|----------------|
| Computer (Windows/Mac/Linux) | Free | — |
| Docker Desktop | Free | ~10 min |
| Telegram account + bot | Free | ~5 min |
| RapidAPI JSearch key | Free tier (10 req/day) or $10/mo | ~5 min |
| OpenAI API key | ~$1–3/month at this usage | ~5 min |
| Gmail account | Free | Already have one |
| Your resume as a `.txt` file | Free | ~5 min |
| Git (to clone this repo) | Free | ~2 min |

**Total estimated cost: $0 for testing, ~$13/month for real daily use**

> 💡 **What is Docker?** Docker is a tool that packages software into "containers" — think of it like a self-contained box with everything pre-installed. We use it so you don't have to manually install n8n and PostgreSQL. It just works.

> 💡 **What is n8n?** n8n (pronounced "n-eight-n") is a visual automation tool. You connect blocks together (called "nodes") and each block does something — fetch data, call an API, send a message. No coding required to use it.

> 💡 **What is PostgreSQL?** A database — basically a spreadsheet that can hold millions of rows and do complex queries. We use it to store all job data, resume versions, and application statuses.

---

## Part 1: Install Docker

Docker is the foundation. Everything else runs inside it.

### Windows

1. Go to: **https://www.docker.com/products/docker-desktop**
2. Click **"Download for Windows"**
3. Run the installer (`Docker Desktop Installer.exe`)
4. When asked about WSL 2, click **"OK"** (this is the Windows Subsystem for Linux, needed for Docker)
5. Restart your computer when prompted
6. After restart, open **Docker Desktop** from the Start menu
7. You should see a **whale icon** in your system tray (bottom right, near the clock)
8. Wait until the whale stops animating — Docker is ready

**Verify it worked** — open Command Prompt (press `Win + R`, type `cmd`, press Enter):
```cmd
docker --version
docker compose version
```
You should see something like:
```
Docker version 25.0.3, build 4debf41
Docker Compose version v2.24.5-desktop.1
```
If you see those, you're good. ✅

### Mac

1. Go to: **https://www.docker.com/products/docker-desktop**
2. Click **"Download for Mac"**
   - Choose **"Mac with Apple chip"** if you have an M1/M2/M3 Mac
   - Choose **"Mac with Intel chip"** if you have an older Mac (pre-2020)
   - Not sure? Click the Apple menu → "About This Mac" — look for "Chip" or "Processor"
3. Open the downloaded `.dmg` file
4. Drag Docker to your Applications folder
5. Open Docker from Applications
6. Approve the system extension when asked (enter your Mac password)
7. Wait for the whale icon in your menu bar (top right) to stop animating

**Verify** in Terminal (press `Cmd + Space`, type "Terminal"):
```bash
docker --version
docker compose version
```

### Linux (Ubuntu/Debian)

Open a terminal and run these commands one by one:
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Add yourself to the docker group (so you don't need sudo every time)
sudo usermod -aG docker $USER

# Apply the group change (or log out and back in)
newgrp docker

# Verify
docker --version
docker compose version
```

### Install Git (needed to clone this repo)

**Windows:** Download from https://git-scm.com/download/win — run installer with all defaults

**Mac:** Open Terminal and run:
```bash
git --version
```
If not installed, macOS will prompt you to install it automatically.

**Linux:**
```bash
sudo apt-get install git -y
```

---

## Part 2: Get Your API Keys

You need 4 things: Telegram bot, RapidAPI key, OpenAI key, and Gmail OAuth. Save each one in a text file as you go — you'll need them in Part 3.

---

### 2.1 Telegram Bot + Chat ID

Telegram is how the agent will notify you. You need to create a "bot" — think of it as a special account that can send you automated messages.

**Create the bot:**
1. Open Telegram on your phone or desktop
2. In the search bar, search for **`@BotFather`** (it has a blue verified checkmark)
3. Start a chat and send: `/newbot`
4. It will ask for a **name** — type anything, e.g. `My Job Agent`
5. It will ask for a **username** — this must end in `bot`, e.g. `myjobagent_john_bot`
   - If the username is taken, try adding numbers: `myjobagent_john123_bot`
6. BotFather replies with your bot token — it looks like:
   ```
   1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ-abc123
   ```
7. **Copy and save this token** — this is your `TELEGRAM_BOT_TOKEN`

> ⚠️ Keep this token secret. Anyone with it can send messages as your bot.

**Get your personal Chat ID:**
1. In Telegram, search for **`@userinfobot`**
2. Start a chat and send any message (like "hi")
3. It replies with your info including: `Id: 987654321`
4. **Copy and save that number** — this is your `TELEGRAM_CHAT_ID`

**Important:** Before the bot can send you messages, you need to start a conversation with it:
1. Search for your new bot by its username (e.g. `@myjobagent_john_bot`)
2. Click **Start** or send any message to it

---

### 2.2 RapidAPI JSearch Key

JSearch is the API that searches job boards for us.

1. Go to: **https://rapidapi.com/**
2. Click **"Sign Up"** — free account, takes 30 seconds
3. In the search bar at the top, search for **"JSearch"**
4. Click on **"JSearch"** by letscrape-6bRBa3QguO5
5. Click **"Subscribe to Test"**
6. Choose a plan:
   - **Basic (Free):** 10 requests/day — good for testing
   - **Basic+ ($10/mo):** 300 requests/day — recommended for daily real use
7. After subscribing, you'll be on the API page. Look for the **"Header Parameters"** section
8. You'll see: `X-RapidAPI-Key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
9. **Copy that long string** — this is your `RAPIDAPI_KEY`

---

### 2.3 OpenAI API Key

OpenAI powers the AI features — scoring jobs, simplifying job descriptions, tailoring your resume.

1. Go to: **https://platform.openai.com/**
2. Sign up or log in
3. Click your profile icon (top right) → **"API keys"** or go to: https://platform.openai.com/api-keys
4. Click **"+ Create new secret key"**
5. Name it: `job-agent`
6. Click **"Create secret key"**
7. **Copy the key immediately** — it starts with `sk-proj-...` and you CANNOT see it again after closing the dialog
8. Save it as your `OPENAI_API_KEY`

**Add credits (required — OpenAI doesn't work without a payment method):**
1. Go to: https://platform.openai.com/settings/billing
2. Click **"Add payment method"**
3. Add a card and add **$5–10 in credits**
4. This is more than enough for months of job searching at this scale (~$1–3/month usage)

---

### 2.4 Gmail OAuth Setup (for email monitoring)

This is the most involved step but you only do it once. It lets n8n read your Gmail to detect job-related emails.

**Step 1 — Create a Google Cloud Project:**
1. Go to: **https://console.cloud.google.com/**
2. Sign in with your Gmail account (the one you use for job applications)
3. At the top, click **"Select a project"** → **"New Project"**
4. Name it: `job-agent`
5. Click **"Create"**
6. Wait a few seconds, then make sure `job-agent` is selected in the top dropdown

**Step 2 — Enable Gmail API:**
1. In the left sidebar: **APIs & Services** → **Library**
2. In the search box, type **"Gmail API"**
3. Click on it → click **"Enable"**
4. Wait for it to enable (green checkmark)

**Step 3 — Create OAuth Credentials:**
1. Left sidebar: **APIs & Services** → **Credentials**
2. Click **"+ Create Credentials"** → **"OAuth client ID"**
3. If prompted to configure consent screen first:
   - Click **"Configure Consent Screen"**
   - Choose **"External"** → **"Create"**
   - App name: `Job Agent`
   - User support email: your email
   - Developer contact: your email
   - Click **"Save and Continue"** through all steps
   - On the last step, click **"Back to Dashboard"**
4. Now back to Credentials → **"+ Create Credentials"** → **"OAuth client ID"**
5. Application type: **"Web application"**
6. Name: `n8n Job Agent`
7. Under **"Authorized redirect URIs"**, click **"+ Add URI"** and enter EXACTLY:
   ```
   http://localhost:5678/rest/oauth2-credential/callback
   ```
8. Click **"Create"**
9. A dialog shows your **Client ID** and **Client Secret** — **copy both and save them**

> 💡 You'll enter these into n8n in Part 5. Keep them handy.

---

## Part 3: Set Up the Project

Now we pull everything together.

**Step 1 — Clone the repository:**

Open a terminal (Command Prompt on Windows, Terminal on Mac/Linux) and run:
```bash
git clone https://github.com/kartikanand0012/n8n-job-search-agent.git
cd n8n-job-search-agent
```

You should now see a folder called `n8n-job-search-agent` with these files:
```
n8n-job-search-agent/
├── README.md
├── SETUP_GUIDE.md          ← you're reading this
├── setup/
│   ├── schema.sql
│   ├── .env.example
│   └── install.sh
├── workflows/
│   ├── 01-job-discovery.json
│   ├── 02-jd-processor.json
│   ├── 03-resume-optimizer.json
│   ├── 04-application-tracker.json
│   ├── 05-daily-summary.json
│   └── 06-email-monitor.json
└── prompts/
    ├── jd-processor.md
    ├── resume-optimizer.md
    └── match-scorer.md
```

**Step 2 — Create your environment file:**

```bash
# Mac/Linux:
cp setup/.env.example .env

# Windows (Command Prompt):
copy setup\.env.example .env
```

**Step 3 — Fill in your API keys:**

Open `.env` in a text editor:
```bash
# Mac/Linux:
nano .env

# Windows:
notepad .env
```

Fill in every value. Here's what a completed `.env` looks like:
```env
# Database (you choose these passwords — make them strong)
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=job_agent
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=MyStr0ngP@ssword123

# APIs (from Part 2)
RAPIDAPI_KEY=a8f3c2d1e4b5a6f7c8d9e0f1a2b3c4d5
OPENAI_API_KEY=sk-proj-abc123def456ghi789jkl012mno345pqr678stu901

# Telegram (from Part 2)
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ
TELEGRAM_CHAT_ID=987654321

# Gmail App Password (NOT your regular password — see below)
EMAIL_IMAP_HOST=imap.gmail.com
EMAIL_IMAP_PORT=993
EMAIL_ADDRESS=yourname@gmail.com
EMAIL_PASSWORD=abcd efgh ijkl mnop

# n8n settings (leave these as-is for local setup)
N8N_HOST=0.0.0.0
N8N_PORT=5678
WEBHOOK_URL=http://localhost:5678

# Resume paths (inside the Docker container — leave as-is)
BASE_RESUME_PATH=/home/node/resumes/base_resume.txt
RESUME_OUTPUT_DIR=/home/node/resumes/tailored/

# Job matching threshold (jobs below this % won't notify you)
MATCH_THRESHOLD=70
JOB_SEARCH_KEYWORDS=Software Engineer,SRE,Backend Developer,Product Analyst,Full Stack Developer
```

> ⚠️ **Important — Gmail App Password:**  
> The `EMAIL_PASSWORD` is NOT your regular Gmail password. You need a special "App Password":
> 1. Go to: https://myaccount.google.com/security
> 2. Make sure **2-Step Verification** is enabled (turn it on if not)
> 3. Search for **"App passwords"** in the search bar on that page
> 4. Click it → Select app: **"Mail"** → Select device: **"Other"** → type `n8n job agent`
> 5. Click **Generate** → you'll see a 16-character password like `abcd efgh ijkl mnop`
> 6. Use that as your `EMAIL_PASSWORD` (spaces are fine)

**Step 4 — Run the install script:**

```bash
# Mac/Linux:
bash setup/install.sh

# Windows: open Git Bash (installed with Git) and run:
bash setup/install.sh
```

**What you'll see:** Docker will download images for n8n and PostgreSQL (first time takes 2–5 minutes depending on internet speed), then create the database tables. You'll see output like:
```
[+] Pulling n8n...
[+] Pulling postgres...
[+] Running 2/2
 ✔ Container n8n-job-search-agent-postgres-1  Started
 ✔ Container n8n-job-search-agent-n8n-1       Started
Creating database tables...
✅ Setup complete!

n8n is running at: http://localhost:5678
```

**Step 5 — Verify both containers are running:**

```bash
docker ps
```

You should see two rows, both showing `Up`:
```
CONTAINER ID   IMAGE        STATUS         NAMES
abc123def456   n8nio/n8n    Up 2 minutes   n8n-job-search-agent-n8n-1
789xyz012abc   postgres:15  Up 2 minutes   n8n-job-search-agent-postgres-1
```

If you see this — ✅ the infrastructure is running. Move to Part 4.

---

## Part 4: Import Workflows into n8n

**What is a workflow?** In n8n, a workflow is a series of connected blocks (called "nodes") that each do one thing. The 6 workflow files in the `workflows/` folder are pre-built automations you just need to import.

**Step 1 — Open n8n:**
1. Open your web browser (Chrome or Firefox recommended)
2. Go to: **http://localhost:5678**
3. You'll see n8n's welcome/signup screen
4. Create a local account — this is just for your machine, not a cloud account:
   - Enter any email (doesn't need to be real for local use)
   - Choose a password
   - Click **"Next"** through the setup questions (you can skip them)
5. You should land on the **n8n dashboard** — a mostly empty page with a canvas

**Step 2 — Import each workflow (do them in order: 01 → 06):**

For EACH of the 6 workflow files:

1. Click the **≡ (hamburger menu)** in the top-left corner
2. Click **"Workflows"** in the sidebar
3. Click the **"+ Add workflow"** button (top right of the workflows list)
4. A blank canvas opens. Click the **≡ menu** again (top left, inside the workflow editor)
5. Click **"Import from File..."**
6. Navigate to your `n8n-job-search-agent/workflows/` folder
7. Select the file (start with `01-job-discovery.json`)
8. The workflow loads — you'll see colored boxes connected by arrows
9. Click **"Save"** (top right, blue button)
10. Click the **back arrow** (top left) to return to the workflows list
11. Repeat for `02`, `03`, `04`, `05`, `06`

**What each workflow looks like after import:**

| Workflow | What you'll see |
|----------|-----------------|
| `01-job-discovery.json` | Starts with a ⏰ clock icon → chain of ~10 boxes |
| `02-jd-processor.json` | Starts with a ⚡ webhook (lightning bolt) icon |
| `03-resume-optimizer.json` | Starts with a ⚡ webhook icon → includes file read/write nodes |
| `04-application-tracker.json` | TWO separate chains: one starting with ⚡, one with ⏰ |
| `05-daily-summary.json` | Starts with ⏰ clock → database query nodes → Telegram node |
| `06-email-monitor.json` | Starts with ⏰ clock → Gmail fetch → AI classify chain |

> ⚠️ You'll notice some nodes have a **red highlight** — that's normal! It means they need credentials (API keys) assigned. We'll fix that in the next step.

> ⚠️ **Do NOT click "Active" yet** — wait until all credentials are set up.

---

## Part 5: Configure Credentials in n8n

**What are credentials in n8n?** Think of them as a secure vault where you store API keys once, and then all your workflows can use them without you hardcoding secrets into every node.

**Access credentials:** Click **≡ menu** → **"Credentials"** in the sidebar

---

### 5.1 PostgreSQL Database Credential

1. Click **"+ Add credential"**
2. Search for **"Postgres"** → click on it
3. Fill in:
   - **Host:** `postgres` ← Type this EXACTLY. NOT "localhost" — inside Docker, services talk to each other by name
   - **Database:** `job_agent`
   - **User:** `n8n_user`
   - **Password:** the password you set in your `.env` file
   - **Port:** `5432`
   - **SSL:** Off (for local setup)
4. Click **"Test connection"** → you should see a **green "Connection tested successfully"** message
5. Name it: `Job Agent DB`
6. Click **"Save"**

> ❌ If the test fails: Double-check that the postgres container is running (`docker ps`), and that the password exactly matches what's in your `.env`

---

### 5.2 OpenAI API Credential

The workflows call OpenAI via HTTP Request nodes (more flexible than the built-in OpenAI node). You'll create a "Header Auth" credential:

1. Click **"+ Add credential"**
2. Search for **"Header Auth"** → click on it
3. Fill in:
   - **Name:** `Authorization`
   - **Value:** `Bearer sk-proj-YOUR_OPENAI_KEY_HERE`
   - (Replace with your actual key — keep the word `Bearer` and the space before the key)
4. Name the credential: `OpenAI API`
5. Click **"Save"**

---

### 5.3 RapidAPI Credential

1. Click **"+ Add credential"**
2. Search for **"Header Auth"** → click on it
3. Fill in:
   - **Name:** `X-RapidAPI-Key`
   - **Value:** your RapidAPI key (just the key, no "Bearer")
4. Name it: `RapidAPI Key`
5. Click **"Save"**

---

### 5.4 Gmail OAuth2 Credential

1. Click **"+ Add credential"**
2. Search for **"Google OAuth2 API"** → click on it
3. Fill in:
   - **Client ID:** the one you saved from Google Cloud Console (Part 2.4)
   - **Client Secret:** the one you saved from Google Cloud Console
4. Click **"Sign in with Google"** or **"Connect my account"**
5. A browser popup opens → sign in with your Gmail account
6. Click **"Allow"** on the permissions screen
7. The popup closes → you should see a green success message
8. Name it: `Gmail OAuth2`
9. Click **"Save"**

> ❌ If you get a redirect error: Make sure you added EXACTLY `http://localhost:5678/rest/oauth2-credential/callback` as the redirect URI in Google Cloud Console (Part 2.4, Step 7). No trailing slash, no https.

---

### 5.5 Telegram Credential

1. Click **"+ Add credential"**
2. Search for **"Telegram API"** → click on it (or use "Header Auth" if Telegram API not found)
3. Fill in your **Bot Token** (from Part 2.1)
4. Name it: `Telegram Bot`
5. Click **"Save"**

---

### 5.6 Link Credentials to Workflow Nodes

Now you need to assign these credentials to the nodes that use them.

For **each of the 6 workflows**:
1. Open the workflow (≡ menu → Workflows → click on it)
2. Look for nodes with a **red border** or a **red warning icon** — these need credentials
3. Click on a red node → a panel opens on the right
4. Find the **"Credential"** dropdown (usually near the top of the panel)
5. Select the appropriate credential from the list:
   - PostgreSQL nodes → `Job Agent DB`
   - HTTP Request nodes calling `api.openai.com` → `OpenAI API` (as Header Auth)
   - HTTP Request nodes calling `jsearch.p.rapidapi.com` → `RapidAPI Key`
   - HTTP Request nodes calling `api.telegram.org` → no credential needed (token is in the URL)
   - Gmail-related nodes → `Gmail OAuth2`
6. Click outside or press Escape to close the panel
7. Click **"Save"** (top right)
8. Repeat for all red nodes in this workflow, then move to the next

> 💡 **Tip:** After assigning a credential, the red highlight disappears. Once all nodes are green, the workflow is ready to activate.

---

## Part 6: Set Up Your Base Resume

The agent needs your resume to tailor it for each job. It must be in **plain text format** (`.txt`), not PDF or Word.

### Convert Your Resume to Plain Text

**If you have a Word document (.docx):**
1. Open it in Microsoft Word or Google Docs
2. File → Save As → choose **Plain Text (.txt)**
3. When asked about encoding, choose **UTF-8**

**If you have a PDF:**
1. Go to: https://pdf2txt.com
2. Upload your PDF → download the `.txt` output
3. Clean it up in a text editor (fix any garbled formatting)

**If you're starting from scratch**, here's the ideal format:

```
YOUR NAME
Job Title | email@gmail.com | Phone | LinkedIn: linkedin.com/in/yourprofile

SUMMARY
2-3 sentence overview of your experience and what you bring.

EXPERIENCE

Job Title | Company Name | Month Year – Month Year
• Built X system that achieved Y result
• Led team of Z developers on ABC project
• Reduced latency by 40% by implementing XYZ

Job Title | Company Name | Month Year – Month Year
• Another bullet point with action verb + what + result
• Keep it quantified wherever possible

SKILLS
Language1, Language2, Framework1, Framework2, Tool1, Tool2, Cloud1

EDUCATION
Degree | Institution | Year – Year

CERTIFICATIONS (if any)
Certification Name | Issuing Body | Year
```

**Key formatting tips:**
- Use `•` bullet points, not hyphens
- Every bullet starts with an action verb (Built, Led, Designed, Optimized, Reduced, Increased)
- Include numbers wherever you can (40% faster, 1M+ users, team of 3)
- No tables, no columns, no graphics — plain text only

### Load the Resume into Docker

Once your `resume.txt` file is ready:

```bash
# Mac/Linux:
docker cp /path/to/your/resume.txt n8n-job-search-agent-n8n-1:/home/node/resumes/base_resume.txt

# Windows (Command Prompt):
docker cp C:\Users\YourName\Documents\resume.txt n8n-job-search-agent-n8n-1:/home/node/resumes/base_resume.txt

# Windows (PowerShell):
docker cp C:\Users\YourName\Documents\resume.txt n8n-job-search-agent-n8n-1:/home/node/resumes/base_resume.txt
```

Replace the path with wherever your file actually is.

**Verify it was copied correctly:**
```bash
docker exec n8n-job-search-agent-n8n-1 cat /home/node/resumes/base_resume.txt
```
You should see your resume text printed in the terminal.

---

## Part 7: Activate and Test

**Order matters.** Activate workflows in this sequence — some workflows need to be listening before others try to call them:

### Activation Order

| Step | Workflow | Why first? |
|------|----------|------------|
| 1st | `02 - JD Processor` | Listens for webhook from Workflow 01 |
| 2nd | `03 - Resume Optimizer` | Listens for manual webhook calls |
| 3rd | `04 - Application Tracker` | Listens for webhook calls |
| 4th | `05 - Daily Summary` | Runs on schedule, no dependencies |
| 5th | `06 - Email Monitor` | Runs on schedule, calls Workflow 04 |
| 6th | `01 - Job Discovery` | Triggers everything — activate LAST |

### How to Activate Each Workflow

1. Open the workflow (≡ menu → Workflows → click name)
2. Find the **toggle switch** in the top right — it says "Inactive"
3. Click it → it turns green and says **"Active"**
4. You should see a brief **"Workflow activated"** notification
5. Go back and repeat for each workflow in the order above

### Test Workflow 01 Manually

After activating all 6, run a manual test:

1. Open **"01 - Job Discovery"** workflow
2. Click the **▶ Execute Workflow** button (play icon, top right area)
3. Watch the nodes execute — they light up one by one:
   - 🟡 Yellow = currently running
   - 🟢 Green = success, with a number showing how many items passed through
   - 🔴 Red = error
4. Click any completed (green) node to see the data that flowed through it
5. This is very useful for debugging!

**After running, check your database:**

```bash
# Connect to the database
docker exec -it n8n-job-search-agent-postgres-1 psql -U n8n_user -d job_agent

# See the jobs that were found
SELECT company_name, role_title, location, scraped_at 
FROM job_postings 
ORDER BY scraped_at DESC 
LIMIT 10;

# See which jobs got scored
SELECT job_id, skill_match_score 
FROM processed_jobs 
ORDER BY skill_match_score DESC 
LIMIT 10;

# Exit the database
\q
```

**Check Telegram:** If any jobs scored ≥ 70%, you should have received a Telegram message. If not, run Workflow 01 once first, wait for Workflow 02 to process the jobs, then check.

---

## Part 8: Daily Usage

Once set up, the system runs on its own. But here's how to interact with it when needed.

### Manually Trigger Resume Tailoring

When you find a job you want to apply to and want a tailored resume:

```bash
# Replace "1" with the actual job ID from your database
curl -X POST http://localhost:5678/webhook/optimize-resume \
  -H "Content-Type: application/json" \
  -d '{"job_id": 1}'
```

**How to find the job ID:**
```bash
docker exec -it n8n-job-search-agent-postgres-1 psql -U n8n_user -d job_agent -c \
  "SELECT id, company_name, role_title FROM job_postings ORDER BY scraped_at DESC LIMIT 20;"
```

### Update Application Status

After you apply to a job, update its status:

```bash
curl -X POST http://localhost:5678/webhook/update-application \
  -H "Content-Type: application/json" \
  -d '{
    "job_id": 1,
    "status": "Applied",
    "notes": "Applied via LinkedIn Easy Apply on 25 March 2026"
  }'
```

**Valid status values:**
- `Not Applied` — found but not applied yet
- `Applied` — application submitted
- `HR Screening` — HR reached out
- `Interview Round 1` — first interview scheduled/done
- `Interview Round 2` — second interview
- `Technical Round` — technical/coding interview
- `Offer` — you got an offer! 🎉
- `Rejected` — moved on
- `Withdrawn` — you withdrew your application

### View Your Entire Application Pipeline

```bash
docker exec -it n8n-job-search-agent-postgres-1 psql -U n8n_user -d job_agent -c "
SELECT 
  jp.company_name,
  jp.role_title,
  at.status,
  at.applied_at,
  at.last_updated,
  at.notes
FROM applications_tracker at 
JOIN job_postings jp ON jp.id = at.job_id 
ORDER BY at.last_updated DESC;"
```

### Get Your Tailored Resumes

List all generated resumes:
```bash
docker exec n8n-job-search-agent-n8n-1 ls /home/node/resumes/tailored/
```

Copy a resume to your local machine:
```bash
# Mac/Linux:
docker cp n8n-job-search-agent-n8n-1:/home/node/resumes/tailored/resume_Google_Software_Engineer.txt ./

# Windows:
docker cp n8n-job-search-agent-n8n-1:/home/node/resumes/tailored/resume_Google_Software_Engineer.txt .
```

### Backup Your Data

Run this weekly to back up all your job data:
```bash
docker exec n8n-job-search-agent-postgres-1 \
  pg_dump -U n8n_user job_agent > backup_$(date +%Y%m%d).sql
```

---

## Troubleshooting

### Common Issues

| Problem | Most Likely Cause | Fix |
|---------|-------------------|-----|
| `docker: command not found` | Docker not installed | Redo Part 1 |
| n8n won't open at localhost:5678 | Container not running | Run `docker ps` — if containers missing, run `docker compose up -d` |
| Postgres node shows "connection refused" | Wrong host value | Use `postgres` not `localhost` as the host |
| Postgres node shows "auth failed" | Wrong password | Check password in `.env` matches credential in n8n |
| No jobs found after running Workflow 01 | RapidAPI key wrong or quota used | Check key in n8n credentials; free tier = 10 req/day |
| Telegram not receiving messages | Bot token or chat ID wrong | Re-check Part 2.1; make sure you messaged the bot first |
| OpenAI node fails with "401 Unauthorized" | API key wrong or no credits | Check key; add credits at platform.openai.com/billing |
| Gmail OAuth fails with redirect error | Redirect URI mismatch | Confirm URI is exactly `http://localhost:5678/rest/oauth2-credential/callback` |
| `install.sh: Permission denied` | Script not executable | Run `chmod +x setup/install.sh` then try again |
| Resume not found error in Workflow 03 | File not copied into Docker | Redo Part 6 with `docker cp` command |

### View Logs

When something goes wrong, logs tell you why:

```bash
# n8n application logs
docker logs n8n-job-search-agent-n8n-1 --tail 50

# PostgreSQL logs
docker logs n8n-job-search-agent-postgres-1 --tail 20

# Follow logs in real-time (Ctrl+C to stop)
docker logs n8n-job-search-agent-n8n-1 --follow
```

**In n8n UI — view execution history:**
1. ≡ Menu → **"Executions"**
2. You'll see every time a workflow ran, with green (success) or red (failed) status
3. Click any execution to see exactly which node failed and what the error was
4. This is the most useful debugging tool

### Stop / Restart Everything

```bash
# Stop all containers
docker compose down

# Start again
docker compose up -d

# Restart just n8n (without restarting the database)
docker compose restart n8n

# Nuclear option — stop and remove all data (WARNING: deletes your job database)
docker compose down -v
```

---

## FAQ

**Q: Is my data private? Are my API keys safe?**

A: Yes — everything runs locally on your computer. Your resume, job data, application history, and API keys are stored only on your machine. The only data that leaves your machine:
- Job search queries → sent to RapidAPI/JSearch
- Job descriptions → sent to OpenAI for processing
- Notifications → sent through Telegram
- Email content → sent to OpenAI for classification

Your resume is processed by OpenAI but never stored by them (they don't retain API inputs by default).

---

**Q: How much does this cost per month?**

| Service | Cost |
|---------|------|
| Docker + n8n + PostgreSQL | Free (self-hosted) |
| RapidAPI JSearch | Free (10 req/day) or ~$10/mo |
| OpenAI | ~$1–3/month |
| Telegram | Free |
| Gmail | Free |
| **Total** | **~$0 testing / ~$13/mo real use** |

---

**Q: Do I need to keep my laptop on 24/7?**

A: For the scheduled tasks (every 6h, 9 AM digest, 30min email check) to work, yes — the machine running Docker needs to be on. Options:
- Run it on a cheap VPS (DigitalOcean $6/mo, AWS EC2 free tier) for 24/7 operation
- Just turn on your laptop during job search periods — it'll catch up on jobs

---

**Q: Can I run this on a server/VPS instead of my laptop?**

A: Yes, and it's better! Steps:
1. Get a VPS (Ubuntu recommended)
2. Follow the Linux Docker install steps
3. Clone the repo and run `install.sh`
4. Change `WEBHOOK_URL` in `.env` to your server's IP: `http://YOUR_IP:5678`
5. Open port 5678 in your firewall

---

**Q: How do I add more job search keywords?**

A: Open workflow `01 - Job Discovery` in n8n → click the **"Set Keywords"** node → find the keywords array and edit it. Example: add `"DevOps Engineer"` to the list.

---

**Q: How do I change the match threshold (currently 70%)?**

A: Open workflow `02 - JD Processor` → find the **IF node** → the condition checks if `skill_match_score >= 70` — change `70` to whatever you want (e.g., `60` for more notifications, `80` for fewer).

---

**Q: The daily summary comes at 9 AM IST — how do I change the time?**

A: Open workflow `05 - Daily Summary` → click the **Schedule Trigger node** → change the cron expression.

Use https://crontab.guru to build cron expressions:
- 9 AM every day: `0 9 * * *`
- 8 AM every weekday: `0 8 * * 1-5`
- 7:30 AM every day: `30 7 * * *`

> Note: n8n runs in UTC time. India is UTC+5:30, so 9 AM IST = `30 3 * * *` in UTC.

---

**Q: I applied to a job — do I need to manually update the tracker?**

A: For now, yes — run the `curl` command in Part 8 to set status to "Applied". The email monitor (Workflow 06) auto-updates status when you receive replies (interview invites, rejections), so after the initial "Applied" update, it largely maintains itself.

---

**Q: Something broke and I want to start completely fresh. How?**

A:
```bash
# WARNING: This deletes ALL your job data and application history
docker compose down -v
docker compose up -d
```

This stops containers and removes all stored data. Re-run `install.sh` to recreate the database tables.

---

## 🎉 You're all set!

Once everything is running:
- Check Telegram for your first job notifications (within 6 hours of activating Workflow 01)
- The 9 AM daily digest will start arriving every morning
- Email monitor will auto-classify any job responses

**Need help?** Open an issue on the GitHub repository.

**Want to customize?** The workflow JSONs are all editable in n8n's visual editor — no coding needed. Each node has a clear description of what it does.

Good luck with your job search! 🚀
