-- DevOps Dashboard Database Seeding
-- Insert admin users and sample data

-- Insert admin user (password: admin123, hashed with bcrypt)
INSERT INTO users (id, email, username, password, "firstName", "lastName", role, "isActive", "createdAt", "updatedAt") 
VALUES 
  ('postgres-1', 'admin@devops.local', 'admin', '$2a$10$rHgPEqT5Yh.YQH9VJ8K1HOxK7D7.1vNw9/F9WF9h9Tz9J0f9hf9hf', 'Admin', 'User', 'ADMIN', true, NOW(), NOW()),
  ('postgres-2', 'user@devops.local', 'user', '$2a$10$rHgPEqT5Yh.YQH9VJ8K1HOxK7D7.1vNw9/F9WF9h9Tz9J0f9hf9hf', 'Regular', 'User', 'USER', true, NOW(), NOW()),
  ('postgres-3', 'viewer@devops.local', 'viewer', '$2a$10$rHgPEqT5Yh.YQH9VJ8K1HOxK7D7.1vNw9/F9WF9h9Tz9J0f9hf9hf', 'Viewer', 'User', 'VIEWER', true, NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- Insert sample notes
INSERT INTO notes (id, title, content, tags, "isPublic", "userId", "createdAt", "updatedAt") 
VALUES 
  ('note-welcome-postgresql', 'Welcome to DevOps Dashboard', 'This is a welcome note for the DevOps Dashboard. You can create, edit, and delete notes to keep track of your operations and maintenance tasks.', ARRAY['welcome', 'getting-started', 'dashboard'], true, 'postgres-1', NOW(), NOW()),
  ('note-best-practices', 'DevOps Best Practices', 'Best practices for DevOps operations:
1. Infrastructure as Code
2. Continuous Integration/Deployment
3. Monitoring and Alerting
4. Security Best Practices
5. Documentation', ARRAY['best-practices', 'devops', 'infrastructure'], true, 'postgres-1', NOW(), NOW()),
  ('note-admin-private', 'Admin Configuration Notes', 'Private notes for system administration and configuration management. Contains sensitive setup information.', ARRAY['admin', 'private', 'configuration'], false, 'postgres-1', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert sample dashboard
INSERT INTO dashboards (id, name, description, config, "isPublic", "createdBy", "createdAt", "updatedAt") 
VALUES 
  ('dashboard-main', 'Main Operations Dashboard', 'Primary dashboard for monitoring DevOps operations', 
   '{"layout": "grid", "refreshInterval": 30, "theme": "dark", "widgets": [{"type": "metrics", "position": {"x": 0, "y": 0, "w": 4, "h": 2}}, {"type": "events", "position": {"x": 4, "y": 0, "w": 4, "h": 2}}]}', 
   true, 'postgres-1', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert sample events
INSERT INTO events (id, type, title, description, severity, source, "userId", metadata, "createdAt") 
VALUES 
  ('event-init-1', 'INFO', 'System Initialized', 'DevOps Dashboard has been successfully initialized', 'INFO', 'system', 'postgres-1', '{"component": "initialization", "status": "success"}', NOW()),
  ('event-deploy-1', 'DEPLOYMENT', 'Application Deployed', 'DevOps Dashboard v2.0.0 deployed successfully', 'INFO', 'ci-cd', 'postgres-1', '{"version": "2.0.0", "environment": "development"}', NOW())
ON CONFLICT (id) DO NOTHING;

-- Display seeding status
SELECT 'Database seeding completed successfully!' as status;
SELECT 'Users created: ' || COUNT(*) as user_count FROM users;
SELECT 'Notes created: ' || COUNT(*) as note_count FROM notes;
SELECT 'Dashboards created: ' || COUNT(*) as dashboard_count FROM dashboards;
SELECT 'Events created: ' || COUNT(*) as event_count FROM events; 