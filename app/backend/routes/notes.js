const express = require('express');
const { getMysqlConnection, getPostgresPool } = require('../database/init');

const router = express.Router();

// GET /api/notes - Get all notes from both databases
router.get('/', async (req, res) => {
  try {
    const mysqlConnection = getMysqlConnection();
    const postgresPool = getPostgresPool();
    
    let allNotes = [];
    
    // Get notes from MySQL
    if (mysqlConnection) {
      try {
        const [mysqlRows] = await mysqlConnection.execute(
          'SELECT id, title, content, created_at, updated_at, database_type FROM notes ORDER BY created_at DESC'
        );
        allNotes = allNotes.concat(mysqlRows);
      } catch (error) {
        console.error('Error fetching MySQL notes:', error);
      }
    }
    
    // Get notes from PostgreSQL
    if (postgresPool) {
      try {
        const client = await postgresPool.connect();
        const postgresResult = await client.query(
          'SELECT id, title, content, created_at, updated_at, database_type FROM notes ORDER BY created_at DESC'
        );
        allNotes = allNotes.concat(postgresResult.rows);
        client.release();
      } catch (error) {
        console.error('Error fetching PostgreSQL notes:', error);
      }
    }
    
    // Sort all notes by created_at descending
    allNotes.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    
    res.json({
      success: true,
      data: allNotes,
      count: allNotes.length
    });
  } catch (error) {
    console.error('Error fetching notes:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch notes'
    });
  }
});

// GET /api/notes/:id - Get a specific note by ID and database type
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { db } = req.query; // mysql or postgres
    
    let note = null;
    
    if (db === 'mysql') {
      const mysqlConnection = getMysqlConnection();
      if (mysqlConnection) {
        const [rows] = await mysqlConnection.execute(
          'SELECT id, title, content, created_at, updated_at, database_type FROM notes WHERE id = ?',
          [id]
        );
        note = rows[0] || null;
      }
    } else if (db === 'postgres') {
      const postgresPool = getPostgresPool();
      if (postgresPool) {
        const client = await postgresPool.connect();
        const result = await client.query(
          'SELECT id, title, content, created_at, updated_at, database_type FROM notes WHERE id = $1',
          [id]
        );
        note = result.rows[0] || null;
        client.release();
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
    console.error('Error fetching note:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch note'
    });
  }
});

// POST /api/notes - Create a new note
router.post('/', async (req, res) => {
  try {
    const { title, content, database } = req.body;
    
    if (!title) {
      return res.status(400).json({
        success: false,
        error: 'Title is required'
      });
    }
    
    const dbToUse = database || 'both'; // mysql, postgres, or both
    const results = [];
    
    // Create note in MySQL
    if ((dbToUse === 'mysql' || dbToUse === 'both')) {
      const mysqlConnection = getMysqlConnection();
      if (mysqlConnection) {
        try {
          const [result] = await mysqlConnection.execute(
            'INSERT INTO notes (title, content, database_type) VALUES (?, ?, ?)',
            [title, content || '', 'mysql']
          );
          
          const [newNote] = await mysqlConnection.execute(
            'SELECT id, title, content, created_at, updated_at, database_type FROM notes WHERE id = ?',
            [result.insertId]
          );
          
          results.push(newNote[0]);
        } catch (error) {
          console.error('Error creating MySQL note:', error);
        }
      }
    }
    
    // Create note in PostgreSQL
    if ((dbToUse === 'postgres' || dbToUse === 'both')) {
      const postgresPool = getPostgresPool();
      console.log('PostgreSQL pool available:', !!postgresPool);
      if (postgresPool) {
        try {
          console.log('Attempting to connect to PostgreSQL...');
          const client = await postgresPool.connect();
          console.log('PostgreSQL client connected successfully');
          
          console.log('Executing PostgreSQL insert query...');
          const result = await client.query(
            'INSERT INTO notes (title, content, database_type) VALUES ($1, $2, $3) RETURNING id, title, content, created_at, updated_at, database_type',
            [title, content || '', 'postgres']
          );
          console.log('PostgreSQL insert successful:', result.rows[0]);
          
          results.push(result.rows[0]);
          client.release();
          console.log('PostgreSQL client released');
        } catch (error) {
          console.error('Error creating PostgreSQL note with details:', {
            message: error.message,
            code: error.code,
            errno: error.errno,
            sqlState: error.sqlState,
            sqlMessage: error.sqlMessage,
            stack: error.stack
          });
        }
      } else {
        console.error('PostgreSQL pool is not available');
      }
    }
    
    if (results.length === 0) {
      return res.status(500).json({
        success: false,
        error: 'Failed to create note in any database'
      });
    }
    
    res.status(201).json({
      success: true,
      data: results,
      message: `Note created in ${results.length} database(s)`
    });
  } catch (error) {
    console.error('Error creating note:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create note'
    });
  }
});

// PUT /api/notes/:id - Update a note
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content, database } = req.body;
    const { db } = req.query; // mysql or postgres
    
    if (!title) {
      return res.status(400).json({
        success: false,
        error: 'Title is required'
      });
    }
    
    let updatedNote = null;
    
    if (db === 'mysql') {
      const mysqlConnection = getMysqlConnection();
      if (mysqlConnection) {
        await mysqlConnection.execute(
          'UPDATE notes SET title = ?, content = ? WHERE id = ?',
          [title, content || '', id]
        );
        
        const [rows] = await mysqlConnection.execute(
          'SELECT id, title, content, created_at, updated_at, database_type FROM notes WHERE id = ?',
          [id]
        );
        updatedNote = rows[0] || null;
      }
    } else if (db === 'postgres') {
      const postgresPool = getPostgresPool();
      if (postgresPool) {
        const client = await postgresPool.connect();
        const result = await client.query(
          'UPDATE notes SET title = $1, content = $2 WHERE id = $3 RETURNING id, title, content, created_at, updated_at, database_type',
          [title, content || '', id]
        );
        updatedNote = result.rows[0] || null;
        client.release();
      }
    }
    
    if (!updatedNote) {
      return res.status(404).json({
        success: false,
        error: 'Note not found or not updated'
      });
    }
    
    res.json({
      success: true,
      data: updatedNote
    });
  } catch (error) {
    console.error('Error updating note:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update note'
    });
  }
});

// DELETE /api/notes/:id - Delete a note
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { db } = req.query; // mysql or postgres
    
    let deleted = false;
    
    if (db === 'mysql') {
      const mysqlConnection = getMysqlConnection();
      if (mysqlConnection) {
        const [result] = await mysqlConnection.execute(
          'DELETE FROM notes WHERE id = ?',
          [id]
        );
        deleted = result.affectedRows > 0;
      }
    } else if (db === 'postgres') {
      const postgresPool = getPostgresPool();
      if (postgresPool) {
        const client = await postgresPool.connect();
        const result = await client.query(
          'DELETE FROM notes WHERE id = $1',
          [id]
        );
        deleted = result.rowCount > 0;
        client.release();
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
    console.error('Error deleting note:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete note'
    });
  }
});

module.exports = router; 