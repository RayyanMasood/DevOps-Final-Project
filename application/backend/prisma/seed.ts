import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seeding...');

  // Hash password for demo users
  const hashedPassword = await bcrypt.hash('admin123', 10);
  
  try {
    // Create admin user
    const adminUser = await prisma.user.upsert({
      where: { email: 'admin@devops.local' },
      update: {},
      create: {
        id: 'postgres-1',
        email: 'admin@devops.local',
        username: 'admin',
        password: hashedPassword,
        firstName: 'Admin',
        lastName: 'User',
        role: 'ADMIN',
      },
    });

    console.log('✅ Admin user created:', adminUser.email);

    // Create regular user
    const regularUser = await prisma.user.upsert({
      where: { email: 'user@devops.local' },
      update: {},
      create: {
        id: 'postgres-2',
        email: 'user@devops.local',
        username: 'user',
        password: hashedPassword,
        firstName: 'Regular',
        lastName: 'User',
        role: 'USER',
      },
    });

    console.log('✅ Regular user created:', regularUser.email);

    // Create viewer user
    const viewerUser = await prisma.user.upsert({
      where: { email: 'viewer@devops.local' },
      update: {},
      create: {
        id: 'postgres-3',
        email: 'viewer@devops.local',
        username: 'viewer',
        password: hashedPassword,
        firstName: 'Viewer',
        lastName: 'User',
        role: 'VIEWER',
      },
    });

    console.log('✅ Viewer user created:', viewerUser.email);

    // Create sample notes
    const note1 = await prisma.note.upsert({
      where: { id: 'note-welcome-postgresql' },
      update: {},
      create: {
        id: 'note-welcome-postgresql',
        title: 'Welcome to DevOps Dashboard',
        content: 'This is a welcome note for the DevOps Dashboard. You can create, edit, and delete notes to keep track of your operations and maintenance tasks.',
        tags: ['welcome', 'getting-started', 'dashboard'],
        isPublic: true,
        userId: adminUser.id,
      },
    });

    const note2 = await prisma.note.upsert({
      where: { id: 'note-best-practices' },
      update: {},
      create: {
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

    const note3 = await prisma.note.upsert({
      where: { id: 'note-admin-private' },
      update: {},
      create: {
        id: 'note-admin-private',
        title: 'Admin Configuration Notes',
        content: 'Private notes for system administration and configuration management. Contains sensitive setup information.',
        tags: ['admin', 'private', 'configuration'],
        isPublic: false,
        userId: adminUser.id,
      },
    });

    console.log('✅ Sample notes created:', [note1.title, note2.title, note3.title]);

    // Create sample dashboard
    const dashboard = await prisma.dashboard.upsert({
      where: { id: 'dashboard-main' },
      update: {},
      create: {
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

    console.log('✅ Sample dashboard created:', dashboard.name);

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

    console.log('✅ Sample events created');

    console.log('🎉 Database seeding completed successfully!');
    console.log('\n📋 Login credentials:');
    console.log('👤 Admin: admin@devops.local / admin123');
    console.log('👤 User: user@devops.local / admin123');
    console.log('👤 Viewer: viewer@devops.local / admin123');

  } catch (error) {
    console.error('❌ Error during seeding:', error);
    throw error;
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  }); 