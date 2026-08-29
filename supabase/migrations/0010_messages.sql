-- G6 — Messaging. FR-33..FR-35. DR-08: messaging limited to users who share a
-- booking or a listing inquiry.
--
-- Exactly one of listing_id/booking_id is set per message - listing_id for a
-- pre-booking inquiry (any customer -> that listing's provider), booking_id for a
-- conversation scoped to one specific booking (only that booking's two parties).
-- Note for the Flutter side: grouping messages into "conversations" for the inbox
-- must key on (booking_id) or (listing_id, other_party_id), NOT listing_id alone -
-- otherwise two different customers inquiring about the same listing would collide
-- into one thread.

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles (id),
  recipient_id uuid not null references public.profiles (id),
  listing_id uuid references public.listings (id),
  booking_id uuid references public.bookings (id),
  content text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint messages_scope_xor check ((listing_id is not null) <> (booking_id is not null))
);

create index messages_sender_id_idx on public.messages (sender_id);
create index messages_recipient_id_idx on public.messages (recipient_id);
create index messages_listing_id_idx on public.messages (listing_id);
create index messages_booking_id_idx on public.messages (booking_id);

alter table public.messages enable row level security;

create policy "messages_select_participant"
on public.messages for select
to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid());

create policy "messages_select_admin"
on public.messages for select
to authenticated
using (public.is_admin());

create policy "messages_insert_own"
on public.messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and sender_id <> recipient_id
  and (
    (booking_id is not null and exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and ((b.customer_id = sender_id and b.provider_id = recipient_id) or (b.provider_id = sender_id and b.customer_id = recipient_id))
    ))
    or
    (listing_id is not null and exists (
      select 1 from public.listings l
      where l.id = listing_id and l.status = 'approved' and l.is_active
        and (l.provider_id = sender_id or l.provider_id = recipient_id)
    ))
  )
);

-- Only the recipient can update a message, and only to mark it read.
create policy "messages_update_recipient"
on public.messages for update
to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

create or replace function public.prevent_message_tampering()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if current_setting('role', true) = 'authenticated' and not public.is_admin() then
    if new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.content is distinct from old.content
       or new.listing_id is distinct from old.listing_id
       or new.booking_id is distinct from old.booking_id then
      raise exception 'Only is_read can be updated';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_prevent_message_tampering
before update on public.messages
for each row execute function public.prevent_message_tampering();
