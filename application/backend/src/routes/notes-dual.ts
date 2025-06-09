import { Router, Request, Response } from 'express';
import { db } from '../database/connection';
import { logger } from '../utils/logger';

const router = Router();

// Helper function to get MySQL connection (with fallback)
const getMySQLConnection = () => {
  try {
    // Try to require mysql2 dynamically to avoid build errors
    const mysql = require('mysql2');
    const connection = mysql.createConnection({
      host: process.env.MYSQL_HOST || 'mysql',
      port: parseInt(process.env.MYSQL_PORT || '3306'),
      user: process.env.MYSQL_USER || 'devops_user',
      password: process.env.MYSQL_PASSWORD || 'devops_password',
      database: process.env.MYSQL_DATABASE || 'devops_dashboard',
    });
    return connection;
  } catch (error) {
    logger.error('MySQL connection not available:', error);
    return null;
  }
};

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

// Get all notes from both databases
router.get('/', async (req: Request, res: Response) => {
  try {
    const { database = 'all' } = req.query;
    
    let postgresNotes: any[] = [];
    let mysqlNotes: any[] = [];

    // Get PostgreSQL notes
    if (database === 'all' || database === 'postgresql') {
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
          
          postgresNotes = (notes as any[]).map(note => ({
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
        }
      } catch (error) {
        logger.error('Error fetching PostgreSQL notes:', error);
      }
    }

    // Get MySQL notes
    if (database === 'all' || database === 'mysql') {
      try {
        const mysqlConn = getMySQLConnection();
        if (mysqlConn) {
          mysqlConn.execute(
            `SELECT n.*, u.username, u.email 
             FROM notes_mysql n 
             LEFT JOIN users_mysql u ON n.user_id = u.id 
             ORDER BY n.created_at DESC`,
            (err: any, rows: any) => {
              if (!err && rows) {
                mysqlNotes = (rows as any[]).map(note => ({
                  id: note.id,
                  title: note.title,
                  content: note.content,
                  tags: note.tags ? JSON.parse(note.tags) : [],
                  isPublic: note.is_public,
                  userId: note.user_id,
                  createdAt: note.created_at,
                  updatedAt: note.updated_at,
                  user: {
                    id: note.user_id,
                    username: note.username,
                    email: note.email
                  },
                  database: 'mysql'
                }));
              }
              mysqlConn.end();
            }
          );
        }
      } catch (error) {
        logger.error('Error fetching MySQL notes:', error);
      }
    }

    // Wait a bit for MySQL query to complete (since it's async)
    await new Promise(resolve => setTimeout(resolve, 100));

    const allNotes = [...postgresNotes, ...mysqlNotes].sort((a, b) => 
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );

    res.json({
      success: true,
      data: allNotes,
      count: allNotes.length,
      sources: {
        postgresql: postgresNotes.length,
        mysql: mysqlNotes.length
      }
    });
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

    let newNote;

    if (database === 'postgresql') {
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
        
        newNote = {
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
        };
      } catch (error) {
        logger.error('Error creating note in PostgreSQL:', error);
        return res.status(500).json({
          success: false,
          error: 'Failed to create note in PostgreSQL'
        });
      }
    } else if (database === 'mysql') {
      // Create in MySQL
      const mysqlConn = getMySQLConnection();
      if (!mysqlConn) {
        return res.status(500).json({
          success: false,
          error: 'MySQL connection not available'
        });
      }

      const defaultUserId = 'mysql-1';
      const noteId = `note-mysql-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

      try {
        await new Promise((resolve, reject) => {
          mysqlConn.execute(
            `INSERT INTO notes_mysql (id, title, content, tags, is_public, user_id) 
             VALUES (?, ?, ?, ?, ?, ?)`,
            [noteId, title, content, JSON.stringify(tags), isPublic, defaultUserId],
            (err: any, result: any) => {
              if (err) {
                reject(err);
              } else {
                resolve(result);
              }
            }
          );
        });

        // Fetch the created note
        const createdNote: any = await new Promise((resolve, reject) => {
          mysqlConn.execute(
            `SELECT n.*, u.username, u.email 
             FROM notes_mysql n 
             LEFT JOIN users_mysql u ON n.user_id = u.id 
             WHERE n.id = ?`,
            [noteId],
            (err: any, rows: any) => {
              mysqlConn.end();
              if (err) {
                reject(err);
              } else {
                resolve(rows);
              }
            }
          );
        });

        const note = (createdNote as any[])[0];
        newNote = {
          id: note.id,
          title: note.title,
          content: note.content,
          tags: note.tags ? JSON.parse(note.tags) : [],
          isPublic: note.is_public,
          userId: note.user_id,
          createdAt: note.created_at,
          updatedAt: note.updated_at,
          user: {
            id: note.user_id,
            username: note.username,
            email: note.email
          },
          database: 'mysql'
        };
      } catch (error) {
        logger.error('Error creating note in MySQL:', error);
        return res.status(500).json({
          success: false,
          error: 'Failed to create note in MySQL'
        });
      }
    }

    res.status(201).json({
      success: true,
      data: newNote
    });
  } catch (error) {
    logger.error('Error in POST /notes:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create note'
    });
  }
});

// Get a specific note by ID from both databases
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    let note = null;

    // Try PostgreSQL first
    try {
      const postgresNote = await db.$queryRaw`
        SELECT 
          n.id, n.title, n.content, n.tags, n."isPublic", n."userId", n."createdAt", n."updatedAt",
          u.username, u.email
        FROM notes n
        LEFT JOIN users u ON n."userId" = u.id
        WHERE n.id = ${id}
      `;

      if (postgresNote && (postgresNote as any[]).length > 0) {
        const noteData = (postgresNote as any[])[0];
        note = {
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
        };
      }
    } catch (error) {
      logger.error('Error fetching note from PostgreSQL:', error);
    }

    // Try MySQL if not found in PostgreSQL
    if (!note) {
      try {
        const mysqlConn = getMySQLConnection();
        if (mysqlConn) {
          const mysqlNote: any = await new Promise((resolve, reject) => {
            mysqlConn.execute(
              `SELECT n.*, u.username, u.email 
               FROM notes_mysql n 
               LEFT JOIN users_mysql u ON n.user_id = u.id 
               WHERE n.id = ?`,
              [id],
              (err: any, rows: any) => {
                mysqlConn.end();
                if (err) {
                  reject(err);
                } else {
                  resolve(rows);
                }
              }
            );
          });

          if (mysqlNote && (mysqlNote as any[]).length > 0) {
            const noteData = (mysqlNote as any[])[0];
            note = {
              id: noteData.id,
              title: noteData.title,
              content: noteData.content,
              tags: noteData.tags ? JSON.parse(noteData.tags) : [],
              isPublic: noteData.is_public,
              userId: noteData.user_id,
              createdAt: noteData.created_at,
              updatedAt: noteData.updated_at,
              user: {
                id: noteData.user_id,
                username: noteData.username,
                email: noteData.email
              },
              database: 'mysql'
            };
          }
        }
      } catch (error) {
        logger.error('Error fetching note from MySQL:', error);
      }
    }

    if (!note) {
      return res.status(404).json({
        success: false,
        error: 'Note not found'
      });
    }

    res.json({
      success: true,
      data: note
    });
  } catch (error) {
    logger.error('Error in GET /notes/:id:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch note'
    });
  }
});

// Delete a note from both databases
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    let deleted = false;

    // Try deleting from PostgreSQL
    try {
      const result = await db.$executeRaw`DELETE FROM notes WHERE id = ${id}`;
      if (result) {
        deleted = true;
      }
    } catch (error) {
      logger.error('Error deleting note from PostgreSQL:', error);
    }

    // Try deleting from MySQL if not deleted from PostgreSQL
    if (!deleted) {
      try {
        const mysqlConn = getMySQLConnection();
        if (mysqlConn) {
          await new Promise((resolve, reject) => {
            mysqlConn.execute(
              'DELETE FROM notes_mysql WHERE id = ?',
              [id],
              (err: any, result: any) => {
                mysqlConn.end();
                if (err) {
                  reject(err);
                } else {
                  if ((result as any).affectedRows > 0) {
                    deleted = true;
                  }
                  resolve(result);
                }
              }
            );
          });
        }
      } catch (error) {
        logger.error('Error deleting note from MySQL:', error);
      }
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