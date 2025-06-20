// Simplified seed script - run manually after database is set up
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { logger } from '../utils/logger';

const prisma = new PrismaClient();

async function main() {
  logger.info('🌱 Starting database seeding...');

  // Hash password for demo users
  const hashedPassword = await bcrypt.hash('admin123', 10);
  
  try {
    // Check if users already exist
    const existingUsers = await prisma.user.count();
    if (existingUsers > 0) {
      logger.info('✅ Database already seeded, skipping...');
      return;
    }

    // Create admin user
    const adminUser = await prisma.user.create({
      data: {
        id: 'postgres-1',
        email: 'admin@devops.local',
        username: 'admin',
        password: hashedPassword,
        firstName: 'Admin',
        lastName: 'User',
        role: 'ADMIN',
      },
    });

    logger.info('✅ Admin user created:', adminUser.email);

    // Create regular user
    const regularUser = await prisma.user.create({
      data: {
        id: 'postgres-2',
        email: 'user@devops.local',
        username: 'user',
        password: hashedPassword,
        firstName: 'Regular',
        lastName: 'User',
        role: 'USER',
      },
    });

    logger.info('✅ Regular user created:', regularUser.email);

    // Create viewer user
    const viewerUser = await prisma.user.create({
      data: {
        id: 'postgres-3',
        email: 'viewer@devops.local',
        username: 'viewer',
        password: hashedPassword,
        firstName: 'Viewer',
        lastName: 'User',
        role: 'VIEWER',
      },
    });

    logger.info('✅ Viewer user created:', viewerUser.email);

    // Create sample notes
    const note1 = await prisma.note.create({
      data: {
        id: 'note-welcome-postgresql',
        title: 'Welcome to DevOps Dashboard',
        content: 'This is a welcome note for the DevOps Dashboard. You can create, edit, and delete notes to keep track of your operations and maintenance tasks.',
        tags: ['welcome', 'getting-started', 'dashboard'],
        isPublic: true,
        userId: adminUser.id,
      },
    });

    const note2 = await prisma.note.create({
      data: {
        id: 'note-best-practices',
        title: 'DevOps Best Practices',
        content: `# DevOps Best Practices

## Infrastructure as Code
- Use version control for all infrastructure configurations
- Implement infrastructure automation
- Maintain environment parity

## Continuous Integration/Deployment
- Automate testing and deployment pipelines
- Implement proper branching strategies
- Monitor deployment metrics

## Monitoring and Logging
- Set up comprehensive monitoring
- Implement centralized logging
- Create meaningful alerts and dashboards`,
        tags: ['best-practices', 'devops', 'infrastructure'],
        isPublic: true,
        userId: adminUser.id,
      },
    });

    const note3 = await prisma.note.create({
      data: {
        id: 'note-admin-private',
        title: 'Admin Configuration Notes',
        content: 'Private notes for system administration and configuration management. Contains sensitive setup information.',
        tags: ['admin', 'private', 'configuration'],
        isPublic: false,
        userId: adminUser.id,
      },
    });

    logger.info('✅ Sample notes created:', [note1.title, note2.title, note3.title]);

    // Create sample dashboard
    const dashboard = await prisma.dashboard.create({
      data: {
        id: 'dashboard-main',
        name: 'Main Operations Dashboard',
        description: 'Primary dashboard for monitoring DevOps operations',
        config: {
          layout: 'grid',
          refreshInterval: 30,
          theme: 'dark',
          widgets: [
            { type: 'metrics', position: { x: 0, y: 0, w: 4, h: 2 } },
            { type: 'events', position: { x: 4, y: 0, w: 4, h: 2 } },
            { type: 'kpis', position: { x: 0, y: 2, w: 8, h: 3 } }
          ]
        },
        createdBy: adminUser.id,
      },
    });

    logger.info('✅ Sample dashboard created:', dashboard.name);

    // Create sample events
    await prisma.event.createMany({
      data: [
        {
          type: 'INFO',
          title: 'System Initialized',
          description: 'DevOps Dashboard has been successfully initialized',
          severity: 'INFO',
          source: 'system',
          metadata: { component: 'initialization', status: 'success' }
        },
        {
          type: 'DEPLOYMENT',
          title: 'Application Deployed',
          description: 'DevOps Dashboard v2.0.0 deployed successfully',
          severity: 'INFO',
          source: 'ci-cd',
          metadata: { version: '2.0.0', environment: 'development' }
        }
      ],
      skipDuplicates: true,
    });

    logger.info('✅ Sample events created');

    logger.info('🎉 Database seeding completed successfully!');
    logger.info('\n📋 Login credentials:');
    logger.info('👤 Admin: admin@devops.local / admin123');
    logger.info('👤 User: user@devops.local / admin123');
    logger.info('👤 Viewer: viewer@devops.local / admin123');

  } catch (error) {
    logger.error('❌ Error during seeding:', error);
    throw error;
  }
}

// Only run if this file is executed directly
if (require.main === module) {
  main()
    .catch((e) => {
      logger.error(e);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}

export { main as seedDatabase }; 