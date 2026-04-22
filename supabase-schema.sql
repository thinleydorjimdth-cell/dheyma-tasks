-- ══════════════════════════════════════════════════════════════════
-- Dheyma CEO Portal — Supabase Schema  v2.0
-- Run in Supabase SQL Editor. Safe to re-run.
-- ══════════════════════════════════════════════════════════════════

-- ── DROP ORDER ────────────────────────────────────────────────────
drop table if exists public.tasks        cascade;
drop table if exists public.todos        cascade;
drop table if exists public.reminders    cascade;
drop table if exists public.settings     cascade;
drop table if exists public.profiles     cascade;
drop function if exists public.handle_new_user cascade;

-- ══════════════════════════════════════════════════════════════════
-- PROFILES  (one row per auth user)
-- ══════════════════════════════════════════════════════════════════
create table public.profiles (
  id              uuid        references auth.users primary key,
  full_name       text        default '',
  role            text        default 'team',        -- 'ceo' | 'unit_head' | 'team'
  business_unit   text        default '',            -- for unit_head scope
  whatsapp        text        default '',            -- e.g. +97512345678
  avatar          text        default '',
  created_at      timestamptz default now()
);

-- auto-create profile row on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- RLS for profiles
alter table public.profiles enable row level security;

-- Any authenticated user can read all profiles (needed for delegation dropdowns)
create policy "profiles_select" on public.profiles
  for select using (auth.uid() is not null);

-- Users can update their own profile; CEO can update anyone's profile
create policy "profiles_update" on public.profiles
  for update using (
    auth.uid() = id
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'ceo'
    )
  );

-- ══════════════════════════════════════════════════════════════════
-- TASKS
-- ══════════════════════════════════════════════════════════════════
create table public.tasks (
  id                  text        primary key,
  user_id             uuid        references auth.users not null,  -- creator / owner
  title               text        not null default '',
  task_type           text        default 'Task',     -- Meeting|Decision|Delegation|Follow-up|Project|Task|Other
  unit                text        default '',
  assignee            text        default '',         -- free-text name
  delegated_to_id     uuid        references auth.users,           -- Supabase UID of delegate
  delegated_to_name   text        default '',         -- display name
  delegated_to_email  text        default '',
  delegation_note     text        default '',
  delegation_status   text        default '',         -- Pending|Accepted|In Progress|Completed|Rejected
  priority            text        default 'Medium',   -- Critical|High|Medium|Low
  status              text        default 'Not Started', -- Not Started|In Progress|Blocked|Done
  due                 text        default '',         -- ISO date string
  reminder            text        default '',
  notes               text        default '',
  subtasks            jsonb       default '[]',
  is_recurring        boolean     default false,
  recur_pattern       text        default '',         -- daily|weekly|monthly
  recur_end_date      text        default '',
  created_at          timestamptz default now()
);

alter table public.tasks enable row level security;

-- SELECT: CEO sees all | unit_head sees their BU | delegate sees delegated tasks | creator sees own
create policy "tasks_select" on public.tasks
  for select using (
    auth.uid() = user_id
    or auth.uid() = delegated_to_id
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'ceo'
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role = 'unit_head'
        and p.business_unit = tasks.unit
    )
  );

-- INSERT: CEO and unit_heads (for their BU) can create tasks
create policy "tasks_insert" on public.tasks
  for insert with check (
    auth.uid() = user_id
    and (
      exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'ceo')
      or exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and p.role = 'unit_head'
          and p.business_unit = unit
      )
    )
  );

-- UPDATE: CEO updates all | unit_head updates their BU | delegate updates delegation_status only
create policy "tasks_update" on public.tasks
  for update using (
    auth.uid() = user_id
    or auth.uid() = delegated_to_id
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'ceo')
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'unit_head' and p.business_unit = tasks.unit
    )
  );

-- DELETE: creator or CEO only
create policy "tasks_delete" on public.tasks
  for delete using (
    auth.uid() = user_id
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'ceo')
  );

-- ══════════════════════════════════════════════════════════════════
-- TODOS
-- ══════════════════════════════════════════════════════════════════
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

-- ══════════════════════════════════════════════════════════════════
-- REMINDERS
-- ══════════════════════════════════════════════════════════════════
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

-- ══════════════════════════════════════════════════════════════════
-- SETTINGS  (key/value store per user)
-- ══════════════════════════════════════════════════════════════════
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

-- ══════════════════════════════════════════════════════════════════
-- HELPER: Promote first user to CEO
-- Run once after creating your account:
--   select set_ceo_role('your@email.com');
-- ══════════════════════════════════════════════════════════════════
create or replace function public.set_ceo_role(email text)
returns void language plpgsql security definer as $$
begin
  update public.profiles
  set role = 'ceo'
  where id = (select id from auth.users u where u.email = email limit 1);
end;
$$;
