-- G7 — Notifications & Alerts, in-app only (no FCM/push - see chat decision). FR-36/37.
--
-- Dispatch stays as DB triggers rather than edge-function code, consistent with every
-- other cross-cutting concern in this project (avg_rating sync, privilege-escalation
-- guards): one mechanism, fully server-side, no client bypass possible. The booking
-- Edge Functions (G4) still do the actual status transitions; this trigger just reacts
-- to the resulting row changes.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id),
  type text not null,
  content text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index notifications_user_id_idx on public.notifications (user_id);

alter table public.notifications enable row level security;

create policy "notifications_select_own"
on public.notifications for select
to authenticated
using (user_id = auth.uid());

create policy "notifications_update_own"
on public.notifications for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- No insert policy: rows are only created by the trigger functions below.
-- No delete policy: no FR calls for dismissing/removing notifications.

create or replace function public.prevent_notification_tampering()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if current_setting('role', true) = 'authenticated' and not public.is_admin() then
    if new.user_id is distinct from old.user_id or new.type is distinct from old.type or new.content is distinct from old.content then
      raise exception 'Only is_read can be updated';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_prevent_notification_tampering
before update on public.notifications
for each row execute function public.prevent_notification_tampering();

-- FR-36: booking status changes -----------------------------------------------

create or replace function public.dispatch_booking_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_listing_title text;
begin
  select title into v_listing_title from public.listings where id = new.listing_id;

  if TG_OP = 'INSERT' then
    insert into public.notifications (user_id, type, content)
    values (new.provider_id, 'booking_requested', 'New booking request for ' || v_listing_title);
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.status = 'accepted' then
      insert into public.notifications (user_id, type, content)
      values (new.customer_id, 'booking_accepted', 'Your booking for ' || v_listing_title || ' was accepted');
    elsif new.status = 'rejected' then
      insert into public.notifications (user_id, type, content)
      values (new.customer_id, 'booking_rejected', 'Your booking for ' || v_listing_title || ' was rejected' || coalesce(' (' || new.reject_reason || ')', ''));
    elsif new.status = 'completed' then
      insert into public.notifications (user_id, type, content)
      values (new.customer_id, 'booking_completed', 'Your booking for ' || v_listing_title || ' was marked completed — leave a review!');
    elsif new.status = 'cancelled' then
      -- Either party can cancel (FR-27) and this trigger can't see who (the Edge
      -- Function writes via the service role, so there's no auth.uid() here) -
      -- notify both; the actor already knows from the action they just took.
      insert into public.notifications (user_id, type, content)
      values (new.customer_id, 'booking_cancelled', 'Your booking for ' || v_listing_title || ' was cancelled');
      insert into public.notifications (user_id, type, content)
      values (new.provider_id, 'booking_cancelled', 'A booking for ' || v_listing_title || ' was cancelled');
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_dispatch_booking_notification
after insert or update of status on public.bookings
for each row execute function public.dispatch_booking_notification();

-- FR-37: new messages -----------------------------------------------------------

create or replace function public.dispatch_message_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sender_name text;
begin
  select name into v_sender_name from public.profiles where id = new.sender_id;
  insert into public.notifications (user_id, type, content)
  values (new.recipient_id, 'new_message', 'New message from ' || coalesce(v_sender_name, 'someone'));
  return new;
end;
$$;

create trigger trg_dispatch_message_notification
after insert on public.messages
for each row execute function public.dispatch_message_notification();
