import { Router, Request, Response } from 'express';

const router = Router();

router.post('/login', (req: Request, res: Response) => {
  res.json({ message: 'Login endpoint - to be implemented' });
});

router.post('/logout', (req: Request, res: Response) => {
  res.json({ message: 'Logout endpoint - to be implemented' });
});

router.post('/register', (req: Request, res: Response) => {
  res.json({ message: 'Register endpoint - to be implemented' });
});

export default router; 