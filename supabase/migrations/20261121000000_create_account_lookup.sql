-- Used by LoginPage to decide between "Welcome back" (password) and
-- "Create your account". Only answers for McGill addresses.
--
-- Note: this lets anyone check whether a McGill address has an account
-- (account enumeration). That's the trade-off of the email-first login flow.

create or replace function public.mcgill_account_exists(p_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when lower(trim(p_email)) !~ '@([a-z0-9-]+\.)*mcgill\.ca$' then false
    else exists (
      select 1 from auth.users u where lower(u.email) = lower(trim(p_email))
    )
  end;
$$;

revoke all on function public.mcgill_account_exists(text) from public;
grant execute on function public.mcgill_account_exists(text) to anon, authenticated;
