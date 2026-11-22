-- More kinds of organizations. Run this file on its own, before
-- 20261122100100: Postgres can't use a new enum value in the same
-- transaction that adds it. Safe to run more than once.

alter type public.group_type add value if not exists 'campus_society';
alter type public.group_type add value if not exists 'faculty_association';
alter type public.group_type add value if not exists 'research_group';
