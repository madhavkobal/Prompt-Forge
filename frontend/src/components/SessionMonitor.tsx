/**
 * SessionMonitor Component
 *
 * Monitors authentication state and handles session expiry gracefully.
 * Shows a toast notification when session expires and redirects to login
 * using React Router (smooth transition without page reload).
 */
import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { useAuthStore } from '@/store/authStore';

export function SessionMonitor() {
  const navigate = useNavigate();
  const { sessionExpired, clearSessionExpired } = useAuthStore();

  useEffect(() => {
    if (sessionExpired) {
      // Show user-friendly notification
      toast.error(
        'Your session has expired. Please log in again.',
        {
          duration: 4000,
          icon: '🔒',
        }
      );

      // Clear the session expired flag
      clearSessionExpired();

      // Redirect to login using React Router (preserves state, no page reload)
      navigate('/login', { replace: true });
    }
  }, [sessionExpired, clearSessionExpired, navigate]);

  return null; // This component doesn't render anything
}
