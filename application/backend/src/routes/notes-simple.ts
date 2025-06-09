import { Router, Request, Response } from 'express';
import { db } from '../database/connection';
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

// Get all notes from PostgreSQL
router.get('/', async (req: Request, res: Response) => {
  try {
    // Check if we can query the notes table directly
    const result = await db.$queryRaw`SELECT COUNT(*) as count FROM notes`;
    const noteCount = (result as any[])[0]?.count || 0;
    
    if (noteCount > 0) {
      // Fetch notes with user information
      const notes = await db.$queryRaw`
        SELECT 
          n.id, n.title, n.content, n.tags, n."isPublic", n."userId", n."createdAt", n."updatedAt",
          u.username, u.email
        FROM notes n
        LEFT JOIN users u ON n."userId" = u.id
        ORDER BY n."createdAt" DESC
      `;
      
      const formattedNotes = (notes as any[]).map(note => ({
        id: note.id,
        title: note.title,
        content: note.content,
        tags: note.tags || [],
        isPublic: note.isPublic,
        userId: note.userId,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        user: {
          id: note.userId,
          username: note.username,
          email: note.email
        },
        database: 'postgresql'
      }));

      res.json({
        success: true,
        data: formattedNotes,
        count: formattedNotes.length,
        sources: {
          postgresql: formattedNotes.length,
          mysql: 0
        }
      });
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

// Create a new note
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
    const noteId = `note-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    try {
      // Insert note directly
      await db.$executeRaw`
        INSERT INTO notes (id, title, content, tags, "isPublic", "userId", "createdAt", "updatedAt")
        VALUES (${noteId}, ${title}, ${content}, ${tags}, ${isPublic}, ${defaultUserId}, NOW(), NOW())
      `;

      // Fetch the created note with user info
      const createdNote = await db.$queryRaw`
        SELECT 
          n.id, n.title, n.content, n.tags, n."isPublic", n."userId", n."createdAt", n."updatedAt",
          u.username, u.email
        FROM notes n
        LEFT JOIN users u ON n."userId" = u.id
        WHERE n.id = ${noteId}
      `;

      const note = (createdNote as any[])[0];
      
      res.status(201).json({
        success: true,
        data: {
          id: note.id,
          title: note.title,
          content: note.content,
          tags: note.tags || [],
          isPublic: note.isPublic,
          userId: note.userId,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          user: {
            id: note.userId,
            username: note.username,
            email: note.email
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

// Get a specific note by ID
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    try {
      const note = await db.$queryRaw`
        SELECT 
          n.id, n.title, n.content, n.tags, n."isPublic", n."userId", n."createdAt", n."updatedAt",
          u.username, u.email
        FROM notes n
        LEFT JOIN users u ON n."userId" = u.id
        WHERE n.id = ${id}
      `;

      if (!note || (note as any[]).length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Note not found'
        });
      }

      const noteData = (note as any[])[0];
      
      res.json({
        success: true,
        data: {
          id: noteData.id,
          title: noteData.title,
          content: noteData.content,
          tags: noteData.tags || [],
          isPublic: noteData.isPublic,
          userId: noteData.userId,
          createdAt: noteData.createdAt,
          updatedAt: noteData.updatedAt,
          user: {
            id: noteData.userId,
            username: noteData.username,
            email: noteData.email
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

// Delete a note
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    try {
      const result = await db.$executeRaw`DELETE FROM notes WHERE id = ${id}`;
      
      if (result) {
        res.json({
          success: true,
          message: 'Note deleted successfully'
        });
      } else {
        res.status(404).json({
          success: false,
          error: 'Note not found'
        });
      }
    } catch (error) {
      logger.error('Error deleting note from PostgreSQL:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to delete note'
      });
    }
  } catch (error) {
    logger.error('Error in DELETE /notes/:id:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete note'
    });
  }
});

export default router; 