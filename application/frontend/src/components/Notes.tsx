import React, { useState, useEffect } from 'react';
import { Plus, Database, Trash2, Eye, Edit3 } from 'lucide-react';

interface Note {
  id: string;
  title: string;
  content: string;
  tags: string[];
  isPublic: boolean;
  userId: string;
  createdAt: string;
  updatedAt: string;
  user?: {
    id: string;
    username: string;
    email: string;
  };
  database: 'postgresql' | 'mysql';
}

interface NotesResponse {
  success: boolean;
  data: Note[];
  count: number;
  sources: {
    postgresql: number;
    mysql: number;
  };
}

const Notes: React.FC = () => {
  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(false);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [selectedDatabase, setSelectedDatabase] = useState<'postgresql' | 'mysql' | 'all'>('all');
  const [formData, setFormData] = useState({
    title: '',
    content: '',
    tags: '',
    isPublic: false,
    database: 'postgresql' as 'postgresql' | 'mysql'
  });

  // Fetch notes from both databases
  const fetchNotes = async () => {
    setLoading(true);
    try {
      const response = await fetch(`/api/notes?database=${selectedDatabase}`);
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data: NotesResponse = await response.json();
      
      if (data.success) {
        setNotes(data.data);
      } else {
        console.error('Failed to fetch notes:', data);
        setNotes([]);
      }
    } catch (error) {
      console.error('Error fetching notes:', error);
      setNotes([]);
    } finally {
      setLoading(false);
    }
  };

  // Create a new note
  const createNote = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const response = await fetch('/api/notes', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...formData,
          tags: formData.tags.split(',').map(tag => tag.trim()).filter(tag => tag)
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      
      if (data.success) {
        setFormData({
          title: '',
          content: '',
          tags: '',
          isPublic: false,
          database: 'postgresql'
        });
        setShowCreateForm(false);
        fetchNotes(); // Refresh the notes list
      } else {
        console.error('Failed to create note:', data);
        alert('Failed to create note. Please try again.');
      }
    } catch (error) {
      console.error('Error creating note:', error);
      alert('Error creating note. Please check your connection and try again.');
    }
  };

  // Delete a note
  const deleteNote = async (id: string) => {
    if (!confirm('Are you sure you want to delete this note?')) {
      return;
    }

    try {
      const response = await fetch(`/api/notes/${id}`, {
        method: 'DELETE',
      });

      const data = await response.json();
      
      if (data.success) {
        fetchNotes(); // Refresh the notes list
      }
    } catch (error) {
      console.error('Error deleting note:', error);
    }
  };

  useEffect(() => {
    fetchNotes();
  }, [selectedDatabase]);

  const getDatabaseColor = (database: string) => {
    return database === 'postgresql' ? 'bg-blue-100 text-blue-800' : 'bg-orange-100 text-orange-800';
  };

  const getDatabaseIcon = (database: string) => {
    return database === 'postgresql' ? '🐘' : '🐬';
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-6xl mx-auto">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Notes Manager</h1>
          <button
            onClick={() => setShowCreateForm(true)}
            className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg hover:bg-primary/90 transition-colors"
          >
            <Plus size={20} />
            Create Note
          </button>
        </div>

        {/* Database Filter */}
        <div className="mb-6">
          <label className="block text-sm font-medium mb-2">Filter by Database:</label>
          <select
            value={selectedDatabase}
            onChange={(e) => setSelectedDatabase(e.target.value as 'postgresql' | 'mysql' | 'all')}
            className="px-3 py-2 border border-border rounded-md bg-background"
          >
            <option value="all">All Databases</option>
            <option value="postgresql">PostgreSQL Only</option>
            <option value="mysql">MySQL Only</option>
          </select>
        </div>

        {/* Create Note Form */}
        {showCreateForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-card border border-border rounded-lg p-6 w-full max-w-md">
              <h2 className="text-xl font-semibold mb-4">Create New Note</h2>
              <form onSubmit={createNote} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-1">Database:</label>
                  <select
                    value={formData.database}
                    onChange={(e) => setFormData({ ...formData, database: e.target.value as 'postgresql' | 'mysql' })}
                    className="w-full px-3 py-2 border border-border rounded-md bg-background"
                  >
                    <option value="postgresql">PostgreSQL</option>
                    <option value="mysql">MySQL</option>
                  </select>
                </div>
                
                <div>
                  <label className="block text-sm font-medium mb-1">Title:</label>
                  <input
                    type="text"
                    value={formData.title}
                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-md bg-background"
                    required
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium mb-1">Content:</label>
                  <textarea
                    value={formData.content}
                    onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-md bg-background h-32"
                    required
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium mb-1">Tags (comma-separated):</label>
                  <input
                    type="text"
                    value={formData.tags}
                    onChange={(e) => setFormData({ ...formData, tags: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-md bg-background"
                    placeholder="tag1, tag2, tag3"
                  />
                </div>
                
                <div className="flex items-center">
                  <input
                    type="checkbox"
                    id="isPublic"
                    checked={formData.isPublic}
                    onChange={(e) => setFormData({ ...formData, isPublic: e.target.checked })}
                    className="mr-2"
                  />
                  <label htmlFor="isPublic" className="text-sm">Make Public</label>
                </div>
                
                <div className="flex gap-2">
                  <button
                    type="submit"
                    className="flex-1 bg-primary text-primary-foreground py-2 rounded-md hover:bg-primary/90 transition-colors"
                  >
                    Create Note
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowCreateForm(false)}
                    className="flex-1 bg-secondary text-secondary-foreground py-2 rounded-md hover:bg-secondary/90 transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Notes List */}
        {loading ? (
          <div className="text-center py-8">
            <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            <p className="mt-2 text-muted-foreground">Loading notes...</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {notes.map((note) => (
              <div key={note.id} className="bg-card border border-border rounded-lg p-6">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${getDatabaseColor(note.database)}`}>
                      {getDatabaseIcon(note.database)} {note.database}
                    </span>
                    {note.isPublic && (
                      <span className="px-2 py-1 bg-green-100 text-green-800 rounded-full text-xs font-medium">
                        <Eye size={12} className="inline mr-1" />
                        Public
                      </span>
                    )}
                  </div>
                  <button
                    onClick={() => deleteNote(note.id)}
                    className="text-destructive hover:text-destructive/80 transition-colors"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
                
                <h3 className="text-lg font-semibold mb-2">{note.title}</h3>
                <p className="text-muted-foreground text-sm mb-3 line-clamp-3">{note.content}</p>
                
                {note.tags.length > 0 && (
                  <div className="flex flex-wrap gap-1 mb-3">
                    {note.tags.map((tag, index) => (
                      <span
                        key={index}
                        className="px-2 py-1 bg-secondary text-secondary-foreground rounded-md text-xs"
                      >
                        #{tag}
                      </span>
                    ))}
                  </div>
                )}
                
                <div className="text-xs text-muted-foreground">
                  <p>Created: {new Date(note.createdAt).toLocaleDateString()}</p>
                  {note.user && <p>By: {note.user.username}</p>}
                </div>
              </div>
            ))}
          </div>
        )}

        {notes.length === 0 && !loading && (
          <div className="text-center py-12">
            <Database size={48} className="mx-auto text-muted-foreground mb-4" />
            <h3 className="text-lg font-semibold mb-2">No Notes Found</h3>
            <p className="text-muted-foreground mb-4">
              Create your first note to get started with the dual-database system.
            </p>
            <button
              onClick={() => setShowCreateForm(true)}
              className="bg-primary text-primary-foreground px-4 py-2 rounded-lg hover:bg-primary/90 transition-colors"
            >
              Create Your First Note
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default Notes; 