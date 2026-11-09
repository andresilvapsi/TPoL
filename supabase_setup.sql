-- Run once in Supabase > SQL Editor. Participants (anon key) can only INSERT; nobody can read through the app.
-- To restart for the real study: truncate the 4 tables and run: alter sequence participant_seq restart;
create table if not exists sessions(participant_id text primary key, condition_no int, gender text, started_at bigint);
create table if not exists decisions(id bigint generated always as identity primary key, participant_id text, condition text, profile_id text, position int, decision text, input text, likes_used int, dwell_total_ms int, dwell_details_ms int, onset_ts bigint, decision_ts bigint, salary_congruency_flag text);
create table if not exists events(id bigint generated always as identity primary key, participant_id text, condition text, profile_id text, type text, ts bigint, x int, y int, v int);
-- profiles: random uuid, NO participant id, NO timestamp column
create table if not exists profiles(id uuid primary key default gen_random_uuid(), email text, name text, age int, gender text, bio text, photo text);
alter table sessions enable row level security; alter table decisions enable row level security; alter table events enable row level security; alter table profiles enable row level security;
create policy "ins" on sessions for insert to anon with check (true);
create policy "ins" on decisions for insert to anon with check (true);
create policy "ins" on events for insert to anon with check (true);
create policy "ins" on profiles for insert to anon with check (true);
-- Global participant numbering + balanced condition assignment (works across all devices)
create sequence if not exists participant_seq;
create or replace function new_participant(n int, g text, forced int default 0) returns json
language plpgsql security definer set search_path=public as $$
declare cn int; s bigint; pid text;
begin
  perform pg_advisory_xact_lock(42);
  s := nextval('participant_seq');
  if forced between 1 and n then cn := forced;
  else select c into cn from generate_series(1,n) c left join (select condition_no k, count(*) m from sessions group by 1) t on t.k=c order by coalesce(t.m,0), random() limit 1;
  end if;
  pid := 'C'||cn||g||(case when s<10 then '0'||s else s::text end);
  insert into sessions(participant_id,condition_no,gender,started_at) values(pid,cn,g,(extract(epoch from now())*1000)::bigint);
  return json_build_object('pid',pid,'cn',cn,'seq',s);
end $$;
grant execute on function new_participant(int,text,int) to anon;
