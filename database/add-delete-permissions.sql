-- Run once on an existing Faculty Atlas Supabase project.
begin;

grant delete on public.profiles, public.attachments to authenticated;

create policy profiles_delete on public.profiles
 for delete to authenticated
 using ((select public.is_hr_editor()));

create policy attachments_delete on public.attachments
 for delete to authenticated
 using ((select public.is_hr_editor()));

create policy faculty_files_delete on storage.objects
 for delete to authenticated
 using (bucket_id = 'faculty-documents' and (select public.is_hr_editor()));

alter table public.attachments drop constraint attachments_profile_id_fkey;
alter table public.attachments add constraint attachments_profile_id_fkey
 foreign key (profile_id) references public.profiles(id) on delete cascade;

alter table public.audit_events drop constraint audit_events_profile_id_fkey;
alter table public.audit_events add constraint audit_events_profile_id_fkey
 foreign key (profile_id) references public.profiles(id) on delete cascade;

commit;
