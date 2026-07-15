-- Multiple chat conversations per user instead of one continuous log.
-- A session is only created once the user actually sends a first message
-- (the app never inserts an empty session when "New chat" is tapped).

create table if not exists public.chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);

alter table public.chat_messages
  add column if not exists session_id uuid references public.chat_sessions (id) on delete cascade;

-- Scoped, paginated message reads for a single conversation.
create index if not exists chat_messages_session_id_created_at_idx
  on public.chat_messages (session_id, created_at);

-- Sessions list ordered by most recently active conversation.
create index if not exists chat_sessions_user_id_last_message_at_idx
  on public.chat_sessions (user_id, last_message_at desc);

alter table public.chat_sessions enable row level security;

drop policy if exists "own chat sessions" on public.chat_sessions;
create policy "own chat sessions" on public.chat_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
