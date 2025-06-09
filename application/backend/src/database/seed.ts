// Simplified seed script - run manually after database is set up
import { logger } from '../utils/logger';

async function main() {
  logger.info('Seed script placeholder - run database setup manually');
  logger.info('1. Run: npx prisma db push');
  logger.info('2. Create sample users and notes through the API');
}

main()
  .catch((e) => {
    logger.error(e);
    process.exit(1);
  }); 