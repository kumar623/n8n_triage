-- Tables used by the IT Ticket Triage Agent (Supabase Postgres).

create table if not exists public.ticket_log (
  id uuid primary key default gen_random_uuid(),
  dedupe_key text not null unique,
  from_email text,
  subject text,
  body text,
  status text not null default 'processing'
    check (status in ('processing', 'classified', 'done', 'rejected', 'timed_out')),
  attempts integer not null default 1,
  category text,
  priority text,
  affected_system text,
  summary text,
  confidence numeric(4,3),
  needs_human boolean,
  reasoning text,
  prompt_version text,
  decision text,
  servicenow_number text,
  suggested_fix text,
  sop_source text,
  jira_key text,
  escalated boolean not null default false,
  pii_masked integer not null default 0,
  pii_types text,
  injection_suspected boolean not null default false,
  received_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.ticket_log is
  'One row per IT ticket handled by the n8n triage workflow. dedupe_key is unique so the same ticket is never processed twice.';

create index if not exists ticket_log_status_idx on public.ticket_log (status);
create index if not exists ticket_log_created_at_idx on public.ticket_log (created_at desc);

create table if not exists public.eval_runs (
  id uuid primary key default gen_random_uuid(),
  run_at timestamptz not null default now(),
  prompt_version text,
  total integer,
  category_correct integer,
  priority_correct integer,
  needs_human_correct integer,
  all_correct integer,
  failures jsonb
);

comment on table public.eval_runs is
  'One row per run of the 20-ticket classifier eval, to compare prompt versions over time.';

create table if not exists public.helpdesk_sessions (
  session_id text primary key,
  requester_email text,
  last_route text check (last_route in ('it', 'hr')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.helpdesk_sessions is
  'One row per helpdesk chat session. Holds the requester email outside the model, so tools can use it while the model only sees a masked tag.';

-- Same shape n8n Postgres Chat Memory creates by itself. Created here so row level security is on from the start.
create table if not exists public.helpdesk_chat_memory (
  id serial primary key,
  session_id varchar(255) not null,
  message jsonb not null
);

comment on table public.helpdesk_chat_memory is
  'Conversation memory for the helpdesk AI agent (n8n Postgres Chat Memory). Holds masked text only.';

create index if not exists helpdesk_chat_memory_session_idx on public.helpdesk_chat_memory (session_id);

create table if not exists public.hr_employees (
  email text primary key,
  country text not null check (country in ('IN', 'UK')),
  role text not null check (role in ('contractor', 'employee', 'manager')),
  annual_leave_total integer not null default 0,
  annual_leave_used integer not null default 0,
  sick_leave_used integer not null default 0,
  updated_at timestamptz not null default now()
);

comment on table public.hr_employees is
  'Demo HR record. Country and role decide which HR policies a person can retrieve (metadata filter). Leave numbers feed the leave balance tool.';

-- Made-up people for the demo and the tests.
insert into public.hr_employees (email, country, role, annual_leave_total, annual_leave_used, sick_leave_used) values
  ('priya.nair@example.com', 'IN', 'employee', 18, 6, 1),
  ('james.carter@example.com', 'UK', 'manager', 25, 10, 0),
  ('alex.reed@example.com', 'UK', 'contractor', 0, 0, 0)
on conflict (email) do nothing;

-- n8n connects as the postgres role, which bypasses row level security.
-- RLS is on with no policies, so the public API roles cannot read these tables.
alter table public.ticket_log enable row level security;
alter table public.eval_runs enable row level security;
alter table public.helpdesk_sessions enable row level security;
alter table public.helpdesk_chat_memory enable row level security;
alter table public.hr_employees enable row level security;
