import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from '@/store/authStore';
import { useEffect } from 'react';
import { authService } from '@/services/authService';

import Login from '@/pages/Login';
import Register from '@/pages/Register';
import Analyzer from '@/pages/Analyzer';
import Prompts from '@/pages/Prompts';
import Templates from '@/pages/Templates';

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
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route
            path="/analyzer"
            element={
              <ProtectedRoute>
                <Analyzer />
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
      </BrowserRouter>
      <Toaster position="top-right" />
    </>
  );
}

export default App;
