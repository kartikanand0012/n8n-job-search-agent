-- =============================================================================
-- Job Search Agent - PostgreSQL Schema
-- Database: job_agent
-- =============================================================================

-- Drop tables if re-running (safe order to handle FK constraints)
DROP TABLE IF EXISTS system_log CASCADE;
DROP TABLE IF EXISTS user_style_memory CASCADE;
DROP TABLE IF EXISTS applications_tracker CASCADE;
DROP TABLE IF EXISTS resume_versions CASCADE;
DROP TABLE IF EXISTS processed_jobs CASCADE;
DROP TABLE IF EXISTS job_postings CASCADE;

-- =============================================================================
-- job_postings: Raw scraped jobs from JSearch API
-- =============================================================================
CREATE TABLE job_postings (
  id                SERIAL PRIMARY KEY,
  company_name      TEXT NOT NULL,
  role_title        TEXT NOT NULL,
  job_description   TEXT,
  required_skills   JSONB,
  experience_required TEXT,
  apply_link        TEXT NOT NULL,
  posted_date       TIMESTAMPTZ,
  source            TEXT,
  location          TEXT,
  salary_info       TEXT,
  scraped_at        TIMESTAMPTZ DEFAULT NOW(),
  is_processed      BOOLEAN DEFAULT FALSE,
  UNIQUE(company_name, role_title, apply_link)
);

COMMENT ON TABLE job_postings IS 'Raw job listings scraped from JSearch API';
COMMENT ON COLUMN job_postings.is_processed IS 'True once workflow 02 has processed this job';

-- =============================================================================
-- processed_jobs: AI-extracted JD analysis + skill match scores
-- =============================================================================
CREATE TABLE processed_jobs (
  id                  SERIAL PRIMARY KEY,
  job_id              INTEGER REFERENCES job_postings(id) ON DELETE CASCADE,
  simplified_jd       TEXT,
  extracted_keywords  JSONB,
  core_skills         JSONB,
  tools_technologies  JSONB,
  responsibilities    JSONB,
  hidden_expectations TEXT,
  ats_keywords        JSONB,
  skill_match_score   FLOAT,
  match_breakdown     JSONB,
  processed_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(job_id)
);

COMMENT ON TABLE processed_jobs IS 'AI-processed JD analysis and skill match data';
COMMENT ON COLUMN processed_jobs.skill_match_score IS 'Float 0-100: match % against Kartik profile';
COMMENT ON COLUMN processed_jobs.match_breakdown IS 'JSON with matched/missing/transferable skills';

-- =============================================================================
-- resume_versions: Tailored resumes per job
-- =============================================================================
CREATE TABLE resume_versions (
  id               SERIAL PRIMARY KEY,
  job_id           INTEGER REFERENCES job_postings(id) ON DELETE SET NULL,
  version_name     TEXT NOT NULL,
  tailored_content TEXT,
  changes_made     JSONB,
  pdf_path         TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE resume_versions IS 'AI-tailored resume variants per job application';
COMMENT ON COLUMN resume_versions.version_name IS 'e.g. resume_google_sre_2024_03';

-- =============================================================================
-- applications_tracker: End-to-end application status tracking
-- =============================================================================
CREATE TABLE applications_tracker (
  id                  SERIAL PRIMARY KEY,
  job_id              INTEGER REFERENCES job_postings(id) ON DELETE CASCADE,
  resume_version_id   INTEGER REFERENCES resume_versions(id) ON DELETE SET NULL,
  status              TEXT DEFAULT 'Not Applied' CHECK (status IN (
    'Not Applied',
    'Applied',
    'HR Screening',
    'Interview Round 1',
    'Interview Round 2',
    'Technical Round',
    'Offer',
    'Rejected',
    'Withdrawn'
  )),
  applied_at          TIMESTAMPTZ,
  last_updated        TIMESTAMPTZ DEFAULT NOW(),
  recruiter_name      TEXT,
  recruiter_email     TEXT,
  notes               TEXT,
  next_action         TEXT,
  UNIQUE(job_id)
);

COMMENT ON TABLE applications_tracker IS 'Application pipeline tracking per job';

-- =============================================================================
-- user_style_memory: Learning from manual resume edits (future ML use)
-- =============================================================================
CREATE TABLE user_style_memory (
  id             SERIAL PRIMARY KEY,
  original_text  TEXT,
  edited_text    TEXT,
  context        TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE user_style_memory IS 'Captures user edits to learn writing style over time';

-- =============================================================================
-- system_log: Audit log for all workflow actions
-- =============================================================================
CREATE TABLE system_log (
  id             SERIAL PRIMARY KEY,
  workflow       TEXT,
  action         TEXT,
  data           JSONB,
  reasoning      TEXT,
  status         TEXT,
  error_message  TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE system_log IS 'Append-only audit log for all n8n workflow events';

-- =============================================================================
-- Indexes
-- =============================================================================
CREATE INDEX idx_job_postings_processed    ON job_postings(is_processed);
CREATE INDEX idx_job_postings_scraped_at   ON job_postings(scraped_at DESC);
CREATE INDEX idx_processed_jobs_match_score ON processed_jobs(skill_match_score DESC);
CREATE INDEX idx_applications_status       ON applications_tracker(status);
CREATE INDEX idx_system_log_workflow       ON system_log(workflow, created_at DESC);

-- Composite index for daily summary queries
CREATE INDEX idx_job_postings_date_processed ON job_postings(scraped_at DESC, is_processed);
CREATE INDEX idx_applications_last_updated ON applications_tracker(last_updated DESC, status);

-- =============================================================================
-- Views (convenience)
-- =============================================================================

-- High-match unapplied jobs (score >= 70, not yet applied)
CREATE VIEW v_hot_jobs AS
  SELECT
    jp.id,
    jp.company_name,
    jp.role_title,
    jp.location,
    jp.apply_link,
    jp.posted_date,
    pj.skill_match_score,
    pj.core_skills,
    pj.ats_keywords,
    at.status
  FROM job_postings jp
  JOIN processed_jobs pj ON pj.job_id = jp.id
  LEFT JOIN applications_tracker at ON at.job_id = jp.id
  WHERE pj.skill_match_score >= 70
    AND (at.status IS NULL OR at.status = 'Not Applied')
  ORDER BY pj.skill_match_score DESC;

-- Application pipeline overview
CREATE VIEW v_pipeline AS
  SELECT
    jp.company_name,
    jp.role_title,
    at.status,
    at.applied_at,
    at.last_updated,
    at.next_action,
    pj.skill_match_score
  FROM applications_tracker at
  JOIN job_postings jp ON jp.id = at.job_id
  LEFT JOIN processed_jobs pj ON pj.job_id = at.job_id
  ORDER BY at.last_updated DESC;

-- Stale applications (applied but no update in 7+ days)
CREATE VIEW v_stale_applications AS
  SELECT
    jp.company_name,
    jp.role_title,
    at.status,
    at.applied_at,
    at.last_updated,
    NOW() - at.last_updated AS days_since_update
  FROM applications_tracker at
  JOIN job_postings jp ON jp.id = at.job_id
  WHERE at.status IN ('Applied', 'HR Screening', 'Interview Round 1', 'Interview Round 2', 'Technical Round')
    AND at.last_updated < NOW() - INTERVAL '7 days'
  ORDER BY at.last_updated ASC;
