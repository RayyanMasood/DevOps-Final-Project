import { Router, Request, Response } from 'express';
import { db } from '../database/connection';
import { getMySQLConnection } from '../database/mysql';
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

// Get all notes from both databases or specific database
router.get('/', async (req: Request, res: Response) => {
  try {
    const { database = 'all' } = req.query;
    let allNotes: any[] = [];
    let postgresCount = 0;
    let mysqlCount = 0;

    // Fetch PostgreSQL notes if requested
    if (database === 'all' || database === 'postgresql') {
      try {
        const postgresNotes = await db.$queryRaw`
          SELECT 
            n.id, n.title, n.content, n.tags, n."isPublic", n."userId", n."createdAt", n."updatedAt",
            u.username, u.email
          FROM notes n
          LEFT JOIN users u ON n."userId" = u.id
          ORDER BY n."createdAt" DESC
        `;
        
        const formattedPostgresNotes = (postgresNotes as any[]).map(note => ({
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

        allNotes = [...allNotes, ...formattedPostgresNotes];
        postgresCount = formattedPostgresNotes.length;
      } catch (error) {
        logger.error('Error fetching PostgreSQL notes:', error);
      }
    }

    // Fetch MySQL notes if requested
    if (database === 'all' || database === 'mysql') {
      try {
        const mysqlConn = getMySQLConnection();
        if (mysqlConn) {
          const mysqlNotes = await new Promise<any[]>((resolve, reject) => {
            const query = `
              SELECT 
                n.id, n.title, n.content, n.tags, n.is_public as isPublic, n.user_id as userId, 
                n.created_at as createdAt, n.updated_at as updatedAt,
                u.username, u.email
              FROM notes_mysql n
              LEFT JOIN users_mysql u ON n.user_id = u.id
              ORDER BY n.created_at DESC
            `;
            
            mysqlConn.execute(query, [], (err: any, results: any) => {
              if (err) {
                reject(err);
              } else {
                resolve(results || []);
              }
            });
          });

          const formattedMysqlNotes = mysqlNotes.map(note => ({
            id: note.id,
            title: note.title,
            content: note.content,
            tags: (() => {
              try {
                return note.tags ? JSON.parse(note.tags) : [];
              } catch (e) {
                return [];
              }
            })(),
            isPublic: note.isPublic,
            userId: note.userId,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            user: {
              id: note.userId,
              username: note.username,
              email: note.email
            },
            database: 'mysql'
          }));

          allNotes = [...allNotes, ...formattedMysqlNotes];
          mysqlCount = formattedMysqlNotes.length;
        }
      } catch (error) {
        logger.error('Error fetching MySQL notes:', error);
      }
    }

    // Sort all notes by creation date (newest first)
    allNotes.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    res.json({
      success: true,
      data: allNotes,
      count: allNotes.length,
      sources: {
        postgresql: postgresCount,
        mysql: mysqlCount
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

    if (database !== 'postgresql' && database !== 'mysql') {
      return res.status(400).json({
        success: false,
        error: 'Unsupported database. Please use "postgresql" or "mysql".'
      });
    }

    if (database === 'postgresql') {
      // PostgreSQL implementation
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
    } else if (database === 'mysql') {
      // MySQL implementation
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
        // Insert note into MySQL
        const insertQuery = `
          INSERT INTO notes_mysql (id, title, content, tags, is_public, user_id, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
        `;
        
        const tagsJson = JSON.stringify(tags);
        
        mysqlConn.execute(insertQuery, [noteId, title, content, tagsJson, isPublic, defaultUserId], (insertErr: any) => {
          if (insertErr) {
            logger.error('Error creating note in MySQL:', insertErr);
            return res.status(500).json({
              success: false,
              error: 'Failed to create note in MySQL'
            });
          }

          // Fetch the created note with user info
          const selectQuery = `
            SELECT 
              n.id, n.title, n.content, n.tags, n.is_public as isPublic, n.user_id as userId, 
              n.created_at as createdAt, n.updated_at as updatedAt,
              u.username, u.email
            FROM notes_mysql n
            LEFT JOIN users_mysql u ON n.user_id = u.id
            WHERE n.id = ?
          `;

          mysqlConn.execute(selectQuery, [noteId], (selectErr: any, results: any) => {
            if (selectErr) {
              logger.error('Error fetching created note from MySQL:', selectErr);
              return res.status(500).json({
                success: false,
                error: 'Failed to fetch created note from MySQL'
              });
            }

            const note = results[0];
            
            res.status(201).json({
              success: true,
              data: {
                id: note.id,
                title: note.title,
                content: note.content,
                tags: (() => {
                  try {
                    return note.tags ? JSON.parse(note.tags) : [];
                  } catch (e) {
                    return [];
                  }
                })(),
                isPublic: note.isPublic,
                userId: note.userId,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt,
                user: {
                  id: note.userId,
                  username: note.username,
                  email: note.email
                },
                database: 'mysql'
              }
            });
          });
        });
      } catch (error) {
        logger.error('Error creating note in MySQL:', error);
        res.status(500).json({
          success: false,
          error: 'Failed to create note in MySQL'
        });
      }
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