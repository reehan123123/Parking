-- Adds optional parking-charge tracking to local-dev parking sessions,
-- mirroring the Supabase production migration. Additive only.

begin;

alter table core.parking_sessions
  add column if not exists total_charge numeric(10, 2) not null default 0,
  add column if not exists paid_amount numeric(10, 2) not null default 0;

alter table core.parking_sessions
  drop constraint if exists parking_sessions_total_charge_check;
alter table core.parking_sessions
  add constraint parking_sessions_total_charge_check
    check (total_charge >= 0);

alter table core.parking_sessions
  drop constraint if exists parking_sessions_paid_amount_check;
alter table core.parking_sessions
  add constraint parking_sessions_paid_amount_check
    check (paid_amount >= 0 and paid_amount <= total_charge);

commit;
