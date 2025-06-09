-- Setup database for Prisma
-- This script prepares the database for Prisma schema deployment

-- Log setup
DO $$
BEGIN
    RAISE NOTICE 'Setting up database for Prisma...';
    RAISE NOTICE 'Database: %', current_database();
    RAISE NOTICE 'User: %', current_user;
    RAISE NOTICE 'Timestamp: %', now();
END $$;

-- Set the search path to public schema for Prisma
ALTER USER devops_user SET search_path = public; 