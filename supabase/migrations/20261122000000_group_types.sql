-- New group types for automatic follows. Kept in its own migration: Postgres
-- can't use a new enum value in the same transaction that adds it.

alter type public.group_type add value if not exists 'campus_society';
alter type public.group_type add value if not exists 'faculty_association';
