-- ══════════════════════════════════════════════════════
-- Dheyma CEO Portal — Supabase Schema  (run in SQL Editor)
-- Safe to re-run: drops and recreates all tables cleanly
-- ══════════════════════════════════════════════════════

drop table if exists public.tasks     cascade;
drop table if exists public.todos     cascade;
drop table if exists public.reminders cascade;
drop table if exists public.settings  cascade;

-- ── TASKS ──────────────────────────────────────────────
create table public.tasks (
  id         text        primary key,
  user_id    uuid        references auth.users not null,
  title      text        not null default '',
  unit       text        default '',
  assignee   text        default '',
  priority   text        default 'Medium',
  status     text        default 'Not Started',
  due        text        default '',
  reminder   text        default '',
  notes      text        default '',
  subtasks   jsonb       default '[]',
  created_at timestamptz default now()
);
alter table public.tasks enable row level security;
create policy "tasks_own" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── TODOS ──────────────────────────────────────────────
create table public.todos (
  id         text        primary key,
  user_id    uuid        references auth.users not null,
  text       text        not null default '',
  notes      text        default '',
  deadline   text        default '',
  done       boolean     default false,
  done_at    text        default '',
  created_at timestamptz default now()
);
alter table public.todos enable row level security;
create policy "todos_own" on public.todos
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── REMINDERS ──────────────────────────────────────────
create table public.reminders (
  id           text        primary key,
  user_id      uuid        references auth.users not null,
  title        text        not null default '',
  notes        text        default '',
  date         text        default '',
  dismissed    boolean     default false,
  dismissed_at text        default '',
  task_id      text        default '',
  created_at   timestamptz default now()
);
alter table public.reminders enable row level security;
create policy "reminders_own" on public.reminders
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── SETTINGS ───────────────────────────────────────────
create table public.settings (
  id         uuid        default gen_random_uuid() primary key,
  user_id    uuid        references auth.users not null,
  key        text        not null,
  value      jsonb,
  created_at timestamptz default now(),
  unique(user_id, key)
);
alter table public.settings enable row level security;
create policy "settings_own" on public.settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
