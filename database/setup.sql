-- Run once in a NEW Supabase project's SQL Editor. One institution per project.
begin;
create table public.hr_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('viewer','editor')),
  created_at timestamptz not null default now()
);
alter table public.hr_members enable row level security;
revoke all on public.hr_members from anon, authenticated;
grant select on public.hr_members to authenticated;
create policy members_read_self on public.hr_members for select to authenticated using (user_id = (select auth.uid()));

create function public.is_hr_member() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.hr_members where user_id=(select auth.uid()));
$$;
create function public.is_hr_editor() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.hr_members where user_id=(select auth.uid()) and role='editor');
$$;
revoke all on function public.is_hr_member(), public.is_hr_editor() from public;
grant execute on function public.is_hr_member(), public.is_hr_editor() to authenticated;

create table public.profiles (
 id uuid primary key default gen_random_uuid(),
 template text not null check (template in ('general','academic','international')),
 data jsonb not null check (jsonb_typeof(data)='object' and length(trim(data->>'name'))>0 and length(trim(data->>'sortName'))>0 and length(trim(data->>'department'))>0 and data ?& array['name','sortName','department']),
 version integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id) on delete set null
);
alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select, delete on public.profiles to authenticated;
grant insert(id,template,data) on public.profiles to authenticated;
grant update(data) on public.profiles to authenticated;
create policy profiles_read on public.profiles for select to authenticated using ((select public.is_hr_member()));
create policy profiles_insert on public.profiles for insert to authenticated with check ((select public.is_hr_editor()));
create policy profiles_update on public.profiles for update to authenticated using ((select public.is_hr_editor())) with check ((select public.is_hr_editor()));
create policy profiles_delete on public.profiles for delete to authenticated using ((select public.is_hr_editor()));
create index profiles_sort_name on public.profiles ((data->>'sortName'));
create index profiles_employee_id on public.profiles ((data->>'employeeId'));

create table public.audit_events (
 id bigint generated always as identity primary key,
 profile_id uuid not null references public.profiles(id) on delete cascade,
 actor uuid references auth.users(id) on delete set null,
 action text not null,
 version integer not null,
 happened_at timestamptz not null default now()
);
alter table public.audit_events enable row level security;
revoke all on public.audit_events from anon, authenticated;
grant select on public.audit_events to authenticated;
create policy audit_read on public.audit_events for select to authenticated using ((select public.is_hr_member()));
create function public.stamp_profile() returns trigger language plpgsql set search_path='' as $$
begin
 new.updated_at=clock_timestamp(); new.updated_by=auth.uid();
 if TG_OP='INSERT' then new.version=1; else new.version=old.version+1; end if;
 return new;
end; $$;
create function public.audit_profile() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.audit_events(profile_id,actor,action,version) values(new.id,auth.uid(),TG_OP,new.version);
 return new;
end; $$;
revoke all on function public.stamp_profile(), public.audit_profile() from public;
create trigger stamp_profile before insert or update on public.profiles for each row execute function public.stamp_profile();
create trigger audit_profile after insert or update on public.profiles for each row execute function public.audit_profile();

create table public.attachments (
 id uuid primary key,
 profile_id uuid not null references public.profiles(id) on delete cascade,
 name text not null check(length(name)>0 and length(name)<=500),
 path text not null unique,
 size integer not null check(size between 0 and 10485760),
 created_at timestamptz not null default now(),
 check(path=profile_id::text || '/' || id::text)
);
alter table public.attachments enable row level security;
revoke all on public.attachments from anon, authenticated;
grant select, insert, delete on public.attachments to authenticated;
create policy attachments_read on public.attachments for select to authenticated using ((select public.is_hr_member()));
create policy attachments_add on public.attachments for insert to authenticated with check ((select public.is_hr_editor()));
create policy attachments_delete on public.attachments for delete to authenticated using ((select public.is_hr_editor()));
create index attachments_profile on public.attachments(profile_id);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('faculty-documents','faculty-documents',false,10485760,array['application/pdf','image/png','image/jpeg']);
create policy faculty_files_read on storage.objects for select to authenticated
 using(bucket_id='faculty-documents' and (select public.is_hr_member()));
create policy faculty_files_insert on storage.objects for insert to authenticated
 with check(bucket_id='faculty-documents' and (select public.is_hr_editor())
 and exists(select 1 from public.profiles where id::text=(storage.foldername(name))[1]));
create policy faculty_files_delete on storage.objects for delete to authenticated
 using(bucket_id='faculty-documents' and (select public.is_hr_editor()));
-- No client deletion, member management, privilege elevation, or public file URLs.
commit;
