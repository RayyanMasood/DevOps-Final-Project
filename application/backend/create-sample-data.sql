-- Insert sample users for PostgreSQL
INSERT INTO users (id, email, username, password, "firstName", "lastName", role, "isActive", "createdAt", "updatedAt") 
VALUES 
  ('postgres-1', 'admin@postgres.local', 'admin_postgres', 'hashed_password_here', 'PostgreSQL', 'Admin', 'ADMIN', true, NOW(), NOW()),
  ('postgres-2', 'user@postgres.local', 'user_postgres', 'hashed_password_here', 'PostgreSQL', 'User', 'USER', true, NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- Insert sample notes for PostgreSQL
INSERT INTO notes (id, title, content, tags, "isPublic", "userId", "createdAt", "updatedAt") 
VALUES 
  ('note-welcome-postgresql', 'Welcome to PostgreSQL Notes', 'This is a sample note stored in PostgreSQL database using Prisma ORM. You can create, edit, and delete notes from here.', ARRAY['postgresql', 'database', 'notes', 'prisma'], true, 'postgres-1', NOW(), NOW()),
  ('note-best-practices', 'Database Best Practices', E'Best practices for PostgreSQL:\n1. Use proper indexing\n2. Normalize your data\n3. Use transactions\n4. Monitor query performance\n5. Regular backups', ARRAY['postgresql', 'best-practices', 'performance'], true, 'postgres-1', NOW(), NOW()),
  ('note-private-dev', 'Private Development Notes', 'These are my private development notes for the project. Contains sensitive information about the architecture.', ARRAY['private', 'development', 'architecture'], false, 'postgres-2', NOW(), NOW())
ON CONFLICT (id) DO NOTHING; 