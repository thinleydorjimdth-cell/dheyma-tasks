-- ─────────────────────────────────────────────
-- Dheyma Tasks — Supabase Schema
-- Run this once in: Supabase → SQL Editor → New query
-- ─────────────────────────────────────────────

-- TASKS
CREATE TABLE IF NOT EXISTS tasks (
  id          TEXT PRIMARY KEY,
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  unit        TEXT    DEFAULT '',
  assignee    TEXT    DEFAULT '',
  priority    TEXT    DEFAULT 'Medium',
  status      TEXT    DEFAULT 'Not Started',
  due         TEXT,
  reminder    TEXT,
  notes       TEXT    DEFAULT '',
  subtasks    JSONB   DEFAULT '[]',
  created_at  TEXT
);

-- TO-DOS
CREATE TABLE IF NOT EXISTS todos (
  id          TEXT PRIMARY KEY,
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  text        TEXT NOT NULL,
  notes       TEXT    DEFAULT '',
  deadline    TEXT,
  done        BOOLEAN DEFAULT FALSE,
  done_at     TEXT,
  created_at  TEXT
);

-- REMINDERS
CREATE TABLE IF NOT EXISTS reminders (
  id           TEXT PRIMARY KEY,
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  date         TEXT,
  notes        TEXT    DEFAULT '',
  dismissed    BOOLEAN DEFAULT FALSE,
  dismissed_at TEXT,
  created_at   TEXT
);

-- SETTINGS  (BU list, etc.)
CREATE TABLE IF NOT EXISTS settings (
  key      TEXT,
  user_id  UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  value    JSONB,
  PRIMARY KEY (key, user_id)
);

-- ── Row Level Security ────────────────────────
ALTER TABLE tasks     ENABLE ROW LEVEL SECURITY;
ALTER TABLE todos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own tasks"     ON tasks     FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own todos"     ON todos     FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own reminders" ON reminders FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own settings"  ON settings  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
