import { Router, Request, Response } from 'express';

const router = Router();

router.get('/', (req: Request, res: Response) => {
  res.json({ message: 'Metrics data - to be implemented' });
});

router.get('/system', (req: Request, res: Response) => {
  res.json({ message: 'System metrics - to be implemented' });
});

export default router; 