import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_BASE = process.env.REACT_APP_API_URL || '/api';

function App() {
  const [notes, setNotes] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [formData, setFormData] = useState({
    title: '',
    content: '',
    database: 'both'
  });
  const [editingNote, setEditingNote] = useState(null);

  // Fetch notes from API
  const fetchNotes = async () => {
    setLoading(true);
    setError('');
    try {
      const response = await axios.get(`${API_BASE}/notes`);
      if (response.data.success) {
        setNotes(response.data.data);
      } else {
        setError('Failed to fetch notes');
      }
    } catch (err) {
      setError('Error connecting to server');
      console.error('Error fetching notes:', err);
    } finally {
      setLoading(false);
    }
  };

  // Create or update note
  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.title.trim()) {
      setError('Title is required');
      return;
    }

    setLoading(true);
    setError('');
    
    try {
      if (editingNote) {
        // Update existing note
        const response = await axios.put(
          `${API_BASE}/notes/${editingNote.id}?db=${editingNote.database_type}`,
          {
            title: formData.title,
            content: formData.content
          }
        );
        
        if (response.data.success) {
          await fetchNotes();
          setEditingNote(null);
        } else {
          setError('Failed to update note');
        }
      } else {
        // Create new note
        const response = await axios.post(`${API_BASE}/notes`, formData);
        
        if (response.data.success) {
          await fetchNotes();
        } else {
          setError('Failed to create note');
        }
      }
      
      setFormData({ title: '', content: '', database: 'both' });
    } catch (err) {
      setError('Error saving note');
      console.error('Error saving note:', err);
    } finally {
      setLoading(false);
    }
  };

  // Delete note
  const handleDelete = async (note) => {
    if (!window.confirm('Are you sure you want to delete this note?')) {
      return;
    }

    setLoading(true);
    try {
      const response = await axios.delete(
        `${API_BASE}/notes/${note.id}?db=${note.database_type}`
      );
      
      if (response.data.success) {
        await fetchNotes();
      } else {
        setError('Failed to delete note');
      }
    } catch (err) {
      setError('Error deleting note');
      console.error('Error deleting note:', err);
    } finally {
      setLoading(false);
    }
  };

  // Start editing note
  const handleEdit = (note) => {
    setEditingNote(note);
    setFormData({
      title: note.title,
      content: note.content || '',
      database: note.database_type
    });
  };

  // Cancel editing
  const handleCancelEdit = () => {
    setEditingNote(null);
    setFormData({ title: '', content: '', database: 'both' });
  };

  // Load notes on component mount
  useEffect(() => {
    fetchNotes();
  }, []);

  return (
    <div className="app">
      <div className="container">
        <header className="header">
          <h1>📝 Notes App</h1>
          <p>Simple note-taking with MySQL & PostgreSQL</p>
        </header>

        {error && (
          <div className="error-message">
            <span>⚠️ {error}</span>
            <button onClick={() => setError('')}>×</button>
          </div>
        )}

        <div className="content">
          <div className="form-section">
            <form onSubmit={handleSubmit} className="note-form">
              <h2>{editingNote ? 'Edit Note' : 'Create New Note'}</h2>
              
              <div className="form-group">
                <label htmlFor="title">Title *</label>
                <input
                  id="title"
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="Enter note title..."
                  required
                />
              </div>

              <div className="form-group">
                <label htmlFor="content">Content</label>
                <textarea
                  id="content"
                  value={formData.content}
                  onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                  placeholder="Enter note content..."
                  rows="4"
                />
              </div>

              {!editingNote && (
                <div className="form-group">
                  <label htmlFor="database">Save to Database</label>
                  <select
                    id="database"
                    value={formData.database}
                    onChange={(e) => setFormData({ ...formData, database: e.target.value })}
                  >
                    <option value="both">Both (MySQL & PostgreSQL)</option>
                    <option value="mysql">MySQL Only</option>
                    <option value="postgres">PostgreSQL Only</option>
                  </select>
                </div>
              )}

              <div className="form-actions">
                <button type="submit" disabled={loading} className="btn-primary">
                  {loading ? '...' : editingNote ? 'Update Note' : 'Create Note'}
                </button>
                {editingNote && (
                  <button type="button" onClick={handleCancelEdit} className="btn-secondary">
                    Cancel
                  </button>
                )}
              </div>
            </form>
          </div>

          <div className="notes-section">
            <div className="notes-header">
              <h2>Your Notes ({notes.length})</h2>
              <button onClick={fetchNotes} disabled={loading} className="btn-refresh">
                🔄 Refresh
              </button>
            </div>

            {loading && notes.length === 0 ? (
              <div className="loading">Loading notes...</div>
            ) : notes.length === 0 ? (
              <div className="empty-state">
                <p>📝 No notes yet. Create your first note above!</p>
              </div>
            ) : (
              <div className="notes-grid">
                {notes.map((note) => (
                  <div key={`${note.database_type}-${note.id}`} className="note-card">
                    <div className="note-header">
                      <h3>{note.title}</h3>
                      <span className={`db-badge ${note.database_type}`}>
                        {note.database_type === 'mysql' ? 'MySQL' : 'PostgreSQL'}
                      </span>
                    </div>
                    
                    {note.content && (
                      <div className="note-content">
                        <p>{note.content}</p>
                      </div>
                    )}
                    
                    <div className="note-footer">
                      <small>
                        Created: {new Date(note.created_at).toLocaleDateString()}
                      </small>
                      <div className="note-actions">
                        <button 
                          onClick={() => handleEdit(note)}
                          className="btn-edit"
                          title="Edit note"
                        >
                          ✏️
                        </button>
                        <button 
                          onClick={() => handleDelete(note)}
                          className="btn-delete"
                          title="Delete note"
                        >
                          🗑️
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default App; 