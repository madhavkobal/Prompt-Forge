/**
 * Security utilities for XSS prevention and input sanitization
 */

/**
 * Sanitize HTML to prevent XSS attacks
 * Removes potentially dangerous HTML tags and attributes
 *
 * @param html - The HTML string to sanitize
 * @returns Sanitized HTML safe for rendering
 */
export function sanitizeHtml(html: string): string {
  if (!html) return '';

  // Create a temporary div to parse HTML
  const temp = document.createElement('div');
  temp.textContent = html; // This escapes all HTML

  return temp.innerHTML;
}

/**
 * Escape HTML special characters
 * Converts HTML special characters to their entity equivalents
 *
 * @param text - The text to escape
 * @returns Escaped text safe for HTML insertion
 */
export function escapeHtml(text: string): string {
  if (!text) return '';

  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

/**
 * Sanitize user input for display
 * Use this for any user-generated content before displaying
 *
 * @param input - User input to sanitize
 * @param allowLineBreaks - Whether to preserve line breaks
 * @returns Sanitized text
 */
export function sanitizeInput(input: string, allowLineBreaks: boolean = false): string {
  if (!input) return '';

  let sanitized = escapeHtml(input);

  if (allowLineBreaks) {
    // Convert line breaks to <br> tags
    sanitized = sanitized.replace(/\n/g, '<br>');
  }

  return sanitized;
}

/**
 * Validate and sanitize URL to prevent javascript: and data: URL attacks
 *
 * @param url - URL to validate
 * @returns Safe URL or empty string if invalid
 */
export function sanitizeUrl(url: string): string {
  if (!url) return '';

  // Remove whitespace
  url = url.trim();

  // Block dangerous protocols
  const dangerousProtocols = ['javascript:', 'data:', 'vbscript:', 'file:'];
  const lowerUrl = url.toLowerCase();

  for (const protocol of dangerousProtocols) {
    if (lowerUrl.startsWith(protocol)) {
      console.warn('Blocked potentially dangerous URL:', url);
      return '';
    }
  }

  // Only allow http, https, mailto, and relative URLs
  const allowedProtocols = /^(https?:\/\/|mailto:|\/|\.\/|\.\.\/)/i;
  if (!allowedProtocols.test(url) && !url.startsWith('#')) {
    console.warn('URL protocol not allowed:', url);
    return '';
  }

  return url;
}

/**
 * CSRF Token Management
 */
class CSRFTokenManager {
  private token: string | null = null;

  /**
   * Get CSRF token from cookie
   */
  getToken(): string | null {
    if (this.token) return this.token;

    // Try to get from cookie
    const match = document.cookie.match(/csrf_token=([^;]+)/);
    if (match) {
      this.token = match[1];
      return this.token;
    }

    return null;
  }

  /**
   * Set CSRF token in memory
   */
  setToken(token: string): void {
    this.token = token;
  }

  /**
   * Clear CSRF token
   */
  clearToken(): void {
    this.token = null;
  }

  /**
   * Add CSRF token to request headers
   */
  getHeaders(): Record<string, string> {
    const token = this.getToken();
    if (!token) {
      console.warn('No CSRF token available');
      return {};
    }

    return {
      'X-CSRF-Token': token
    };
  }
}

export const csrfTokenManager = new CSRFTokenManager();

/**
 * Secure localStorage wrapper with encryption (basic XOR for demo)
 * In production, consider using Web Crypto API for proper encryption
 */
export class SecureStorage {
  private static encode(data: string): string {
    // Basic obfuscation (NOT cryptographically secure)
    // In production, use Web Crypto API
    return btoa(data);
  }

  private static decode(data: string): string {
    try {
      return atob(data);
    } catch {
      return '';
    }
  }

  /**
   * Securely store data in localStorage
   */
  static setItem(key: string, value: string): void {
    try {
      const encoded = this.encode(value);
      localStorage.setItem(key, encoded);
    } catch (error) {
      console.error('Failed to store item securely:', error);
    }
  }

  /**
   * Securely retrieve data from localStorage
   */
  static getItem(key: string): string | null {
    try {
      const encoded = localStorage.getItem(key);
      if (!encoded) return null;
      return this.decode(encoded);
    } catch (error) {
      console.error('Failed to retrieve item securely:', error);
      return null;
    }
  }

  /**
   * Remove item from localStorage
   */
  static removeItem(key: string): void {
    localStorage.removeItem(key);
  }

  /**
   * Clear all items from localStorage
   */
  static clear(): void {
    localStorage.clear();
  }
}

/**
 * Content Security Policy violation reporter
 */
export function setupCSPReporting(): void {
  // Listen for CSP violations
  document.addEventListener('securitypolicyviolation', (e) => {
    console.error('CSP Violation:', {
      blockedURI: e.blockedURI,
      violatedDirective: e.violatedDirective,
      originalPolicy: e.originalPolicy,
      sourceFile: e.sourceFile,
      lineNumber: e.lineNumber,
    });

    // In production, send this to your logging service
    // Example: sendToLoggingService({ type: 'csp_violation', details: e });
  });
}

/**
 * Validate email format
 */
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  return emailRegex.test(email);
}

/**
 * Password strength validator
 */
export interface PasswordStrength {
  isValid: boolean;
  score: number; // 0-100
  errors: string[];
  suggestions: string[];
}

export function validatePasswordStrength(password: string): PasswordStrength {
  const errors: string[] = [];
  const suggestions: string[] = [];
  let score = 0;

  // Length check
  if (password.length < 8) {
    errors.push('Password must be at least 8 characters long');
  } else {
    score += 25;
  }

  // Uppercase check
  if (!/[A-Z]/.test(password)) {
    errors.push('Password must contain at least one uppercase letter');
    suggestions.push('Add uppercase letters');
  } else {
    score += 25;
  }

  // Lowercase check
  if (!/[a-z]/.test(password)) {
    errors.push('Password must contain at least one lowercase letter');
    suggestions.push('Add lowercase letters');
  } else {
    score += 25;
  }

  // Number check
  if (!/\d/.test(password)) {
    errors.push('Password must contain at least one number');
    suggestions.push('Add numbers');
  } else {
    score += 15;
  }

  // Special character check
  if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
    suggestions.push('Consider adding special characters for extra security');
  } else {
    score += 10;
  }

  // Common passwords check
  const commonPasswords = ['password', '12345678', 'qwerty', 'abc123', 'password123'];
  if (commonPasswords.includes(password.toLowerCase())) {
    errors.push('Password is too common');
    score = 0;
  }

  return {
    isValid: errors.length === 0,
    score,
    errors,
    suggestions
  };
}

/**
 * Rate limiting for client-side actions
 */
export class ClientRateLimiter {
  private attempts: Map<string, number[]> = new Map();

  /**
   * Check if action is rate limited
   *
   * @param key - Unique key for the action
   * @param maxAttempts - Maximum attempts allowed
   * @param windowMs - Time window in milliseconds
   * @returns true if action is allowed, false if rate limited
   */
  checkLimit(key: string, maxAttempts: number, windowMs: number): boolean {
    const now = Date.now();
    const timestamps = this.attempts.get(key) || [];

    // Remove old timestamps outside the window
    const validTimestamps = timestamps.filter(t => now - t < windowMs);

    if (validTimestamps.length >= maxAttempts) {
      return false; // Rate limited
    }

    // Add new timestamp
    validTimestamps.push(now);
    this.attempts.set(key, validTimestamps);

    return true; // Allowed
  }

  /**
   * Reset rate limit for a key
   */
  reset(key: string): void {
    this.attempts.delete(key);
  }
}

export const rateLimiter = new ClientRateLimiter();
