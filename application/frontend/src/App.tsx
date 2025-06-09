import { Routes, Route } from 'react-router-dom';
import { Helmet } from 'react-helmet-async';

// Import components
import Notes from './components/Notes';

function App() {
  return (
    <>
      <Helmet>
        <title>DevOps Dashboard</title>
        <meta name="description" content="Modern DevOps Dashboard - Real-time monitoring and analytics" />
      </Helmet>
      
      <div className="min-h-screen bg-background text-foreground">
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/notes" element={<Notes />} />
          <Route path="/login" element={<LoginPage />} />
          {/* Add more routes as needed */}
        </Routes>
      </div>
    </>
  );
}

// Temporary placeholder components
function HomePage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-4xl mx-auto text-center">
        <h1 className="text-4xl font-bold mb-4">DevOps Dashboard</h1>
        <p className="text-xl text-muted-foreground mb-8">
          Modern real-time monitoring and analytics platform
        </p>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
          <div className="bg-card border border-border rounded-lg p-6">
            <h3 className="text-lg font-semibold mb-2">Real-time Monitoring</h3>
            <p className="text-muted-foreground">
              Monitor your infrastructure and applications in real-time with WebSocket-powered updates.
            </p>
          </div>
          
          <div className="bg-card border border-border rounded-lg p-6">
            <h3 className="text-lg font-semibold mb-2">Modern Tech Stack</h3>
            <p className="text-muted-foreground">
              Built with React 18, TypeScript, Tailwind CSS, and Vite for optimal performance.
            </p>
          </div>
          
          <div className="bg-card border border-border rounded-lg p-6">
            <h3 className="text-lg font-semibold mb-2">DevOps Ready</h3>
            <p className="text-muted-foreground">
              Containerized with Docker, includes health checks, and production-ready configurations.
            </p>
          </div>
        </div>
        
        <div className="mt-8 flex gap-4 justify-center">
          <a
            href="/dashboard"
            className="inline-flex items-center px-6 py-3 bg-primary text-primary-foreground rounded-lg font-medium hover:bg-primary/90 transition-colors"
          >
            View Dashboard
          </a>
          <a
            href="/notes"
            className="inline-flex items-center px-6 py-3 bg-secondary text-secondary-foreground rounded-lg font-medium hover:bg-secondary/90 transition-colors"
          >
            Manage Notes
          </a>
        </div>
      </div>
    </div>
  );
}

function DashboardPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">Dashboard</h1>
      <div className="bg-card border border-border rounded-lg p-6">
        <p className="text-muted-foreground">
          Dashboard components will be implemented here. This includes:
        </p>
        <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
          <li>• Real-time KPI widgets</li>
          <li>• Interactive charts and graphs</li>
          <li>• System health monitoring</li>
          <li>• Event log display</li>
          <li>• WebSocket live updates</li>
        </ul>
      </div>
    </div>
  );
}

function LoginPage() {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="max-w-md w-full mx-auto">
        <div className="bg-card border border-border rounded-lg p-8">
          <h2 className="text-2xl font-bold text-center mb-6">Login</h2>
          <p className="text-center text-muted-foreground">
            Authentication components will be implemented here.
          </p>
        </div>
      </div>
    </div>
  );
}

export default App; 