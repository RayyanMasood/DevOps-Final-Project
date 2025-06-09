import { Router, Request, Response } from 'express';

const router = Router();

router.get('/', (req: Request, res: Response) => {
  res.json({ message: 'Events data - to be implemented' });
});

router.post('/', (req: Request, res: Response) => {
  res.json({ message: 'Create event - to be implemented' });
});

export default router; 