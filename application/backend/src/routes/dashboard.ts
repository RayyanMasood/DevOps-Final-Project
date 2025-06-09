import { Router, Request, Response } from 'express';

const router = Router();

router.get('/', (req: Request, res: Response) => {
  res.json({ message: 'Dashboard data - to be implemented' });
});

router.get('/summary', (req: Request, res: Response) => {
  res.json({ message: 'Dashboard summary - to be implemented' });
});

export default router; 