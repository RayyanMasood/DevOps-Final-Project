import { Request, Response, NextFunction } from 'express';
 
export const authMiddleware = (req: Request, res: Response, next: NextFunction) => {
  // TODO: Implement actual authentication logic
  // For now, just pass through
  next();
}; 