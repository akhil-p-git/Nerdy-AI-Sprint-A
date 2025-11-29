import { createContext, useContext, useState, useEffect } from 'react';
import type { ReactNode } from 'react';
import { api } from '../api/client';

interface Student {
  id: number;
  email: string;
  firstName: string;
  lastName: string;
}

interface AuthContextType {
  student: Student | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (nerdyToken: string) => Promise<void>;
  logout: () => void;
  refreshToken: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [student, setStudent] = useState<Student | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      fetchCurrentUser();
    } else {
      setIsLoading(false);
    }
  }, []);

  const fetchCurrentUser = async () => {
    try {
      const response = await api.get('/api/v1/auth/me');
      setStudent(response.data.student);
    } catch (error) {
      localStorage.removeItem('token');
      localStorage.removeItem('refreshToken');
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (nerdyToken: string) => {
    const response = await api.post('/api/v1/auth/login', { nerdy_token: nerdyToken });
    localStorage.setItem('token', response.data.token);
    localStorage.setItem('refreshToken', response.data.refresh_token);
    setStudent(response.data.student);
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('refreshToken');
    setStudent(null);
  };

  const refreshToken = async () => {
    const refresh = localStorage.getItem('refreshToken');
    if (refresh) {
      const response = await api.post('/api/v1/auth/refresh', { refresh_token: refresh });
      localStorage.setItem('token', response.data.token);
    }
  };

  return (
    <AuthContext.Provider value={{
      student,
      isAuthenticated: !!student,
      isLoading,
      login,
      logout,
      refreshToken
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
};

