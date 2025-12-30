import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from '@/store/authStore';
import { useEffect, lazy, Suspense } from 'react';
import { authService } from '@/services/authService';
import { SessionMonitor } from '@/components/SessionMonitor';

// Lazy load pages for code splitting
const Login = lazy(() => import('@/pages/Login'));
const Register = lazy(() => import('@/pages/Register'));
const AnalyzerEnhanced = lazy(() => import('@/pages/AnalyzerEnhanced'));
const Prompts = lazy(() => import('@/pages/Prompts'));
const Templates = lazy(() => import('@/pages/Templates'));

// Loading component for suspense fallback
function PageLoader() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-50 to-primary-100 flex items-center justify-center">
      <div className="text-center">
        <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        <p className="mt-4 text-gray-600">Loading...</p>
      </div>
    </div>
  );
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated());

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

function App() {
  const { token, setUser } = useAuthStore();

  useEffect(() => {
    if (token) {
      authService
        .getCurrentUser()
        .then((user) => setUser(user))
        .catch(() => {
          // Token is invalid, logout
          useAuthStore.getState().logout();
        });
    }
  }, [token, setUser]);

  return (
    <>
      <BrowserRouter>
        <SessionMonitor />
        <Suspense fallback={<PageLoader />}>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route
              path="/analyzer"
              element={
                <ProtectedRoute>
                  <AnalyzerEnhanced />
                </ProtectedRoute>
              }
            />
            <Route
              path="/prompts"
              element={
                <ProtectedRoute>
                  <Prompts />
                </ProtectedRoute>
              }
            />
            <Route
              path="/templates"
              element={
                <ProtectedRoute>
                  <Templates />
                </ProtectedRoute>
              }
            />
            <Route path="/" element={<Navigate to="/analyzer" replace />} />
          </Routes>
        </Suspense>
      </BrowserRouter>
      <Toaster position="top-right" />
    </>
  );
}

export default App;
