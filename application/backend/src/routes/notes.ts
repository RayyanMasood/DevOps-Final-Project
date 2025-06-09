import { Router, Request, Response } from 'express';
import { db } from '../database/connection';
// import { getMySQLConnection } from '../database/mysql'; // Temporarily disabled
import { logger } from '../utils/logger';

const router = Router();

// Health check for notes endpoint
router.get('/health', async (req: Request, res: Response) => {
  try {
    res.json({
      success: true,
      message: 'Notes API is running',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Notes API health check failed'
    });
  }
});

// Get all notes from PostgreSQL only (MySQL temporarily disabled)
router.get('/', async (req: Request, res: Response) => {
  try {
    const { database = 'postgresql' } = req.query;
    
    let postgresNotes: any[] = [];

    // Get PostgreSQL notes only
    if (database === 'all' || database === 'postgresql') {
      try {
        postgresNotes = await db.user.findMany({
          include: {
            notes: {
              orderBy: {
                createdAt: 'desc'
              }
            }
          }
        });
        
        // Flatten notes with user info
        const allNotes = postgresNotes.flatMap(user => 
          user.notes.map(note => ({
            ...note,
            user: {
              id: user.id,
              username: user.username,
              email: user.email
            },
            database: 'postgresql'
          }))
        );
        
        res.json({
          success: true,
          data: allNotes,
          count: allNotes.length,
          sources: {
            postgresql: allNotes.length,
            mysql: 0 // Temporarily disabled
          }
        });
        
      } catch (error) {
        logger.error('Error fetching PostgreSQL notes:', error);
        res.status(500).json({
          success: false,
          error: 'Failed to fetch notes from PostgreSQL'
        });
      }
    } else {
      res.json({
        success: true,
        data: [],
        count: 0,
        sources: {
          postgresql: 0,
          mysql: 0
        }
      });
    }
  } catch (error) {
    logger.error('Error in GET /notes:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch notes'
    });
  }
});

// Create a new note in PostgreSQL only
router.post('/', async (req: Request, res: Response) => {
  try {
    const { title, content, tags = [], isPublic = false, database = 'postgresql' } = req.body;
    
    if (!title || !content) {
      return res.status(400).json({
        success: false,
        error: 'Title and content are required'
      });
    }

    if (database !== 'postgresql') {
      return res.status(400).json({
        success: false,
        error: 'MySQL support temporarily disabled. Please use PostgreSQL.'
      });
    }

    // For demo purposes, use a default user ID
    const defaultUserId = 'postgres-1';

    try {
      // Create in PostgreSQL
      const newNote = await db.user.update({
        where: { id: defaultUserId },
        data: {
          notes: {
            create: {
              title,
              content,
              tags,
              isPublic
            }
          }
        },
        include: {
          notes: {
            orderBy: {
              createdAt: 'desc'
            },
            take: 1
          }
        }
      });

      const createdNote = newNote.notes[0];
      
      res.status(201).json({
        success: true,
        data: {
          ...createdNote,
          user: {
            id: newNote.id,
            username: newNote.username,
            email: newNote.email
          },
          database: 'postgresql'
        }
      });
    } catch (error) {
      logger.error('Error creating note in PostgreSQL:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to create note in PostgreSQL'
      });
    }
  } catch (error) {
    logger.error('Error in POST /notes:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create note'
    });
  }
});

// Get a specific note by ID from PostgreSQL only
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    try {
      const noteWithUser = await db.user.findFirst({
        where: {
          notes: {
            some: { id }
          }
        },
        include: {
          notes: {
            where: { id }
          }
        }
      });

      if (!noteWithUser || noteWithUser.notes.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Note not found'
        });
      }

      const note = noteWithUser.notes[0];
      
      res.json({
        success: true,
        data: {
          ...note,
          user: {
            id: noteWithUser.id,
            username: noteWithUser.username,
            email: noteWithUser.email
          },
          database: 'postgresql'
        }
      });
    } catch (error) {
      logger.error('Error fetching note from PostgreSQL:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch note'
      });
    }
  } catch (error) {
    logger.error('Error in GET /notes/:id:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch note'
    });
  }
});

// Delete a note from PostgreSQL only
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    let deleted = false;

    try {
      const result = await db.user.update({
        where: {
          notes: {
            some: { id }
          }
        },
        data: {
          notes: {
            delete: { id }
          }
        }
      });
      
      if (result) {
        deleted = true;
      }
    } catch (error) {
      logger.error('Error deleting note from PostgreSQL:', error);
    }

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Note not found'
      });
    }

    res.json({
      success: true,
      message: 'Note deleted successfully'
    });
  } catch (error) {
    logger.error('Error in DELETE /notes/:id:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete note'
    });
  }
});

export default router; 