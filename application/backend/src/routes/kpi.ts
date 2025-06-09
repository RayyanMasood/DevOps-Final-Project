import { Router, Request, Response } from 'express';

const router = Router();

router.get('/', (req: Request, res: Response) => {
  res.json({ message: 'KPI data - to be implemented' });
});

router.post('/', (req: Request, res: Response) => {
  res.json({ message: 'Create KPI - to be implemented' });
});

export default router; 