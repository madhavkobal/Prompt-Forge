/**
 * Environment Configuration
 *
 * This file centralizes all environment variable access.
 * All variables must be prefixed with VITE_ to be exposed to the browser.
 */

export const config = {
  // API Configuration
  apiUrl: import.meta.env.VITE_API_URL || 'http://localhost:8000',
  apiVersion: '/api/v1',

  // Application Settings
  appName: import.meta.env.VITE_APP_NAME || 'PromptForge',
  appVersion: import.meta.env.VITE_APP_VERSION || '1.0.0',
  isDevelopment: import.meta.env.DEV,
  isProduction: import.meta.env.PROD,

  // Debug Mode
  debug: import.meta.env.VITE_DEBUG === 'true',

  // Analytics (Optional)
  gaMeasurementId: import.meta.env.VITE_GA_MEASUREMENT_ID,
  sentryDsn: import.meta.env.VITE_SENTRY_DSN,

  // Feature Flags
  enableExperimental: import.meta.env.VITE_ENABLE_EXPERIMENTAL === 'true',
  enableDarkMode: import.meta.env.VITE_ENABLE_DARK_MODE !== 'false', // Enabled by default
} as const;

/**
 * Get the full API base URL including version
 */
export function getApiBaseUrl(): string {
  return `${config.apiUrl}${config.apiVersion}`;
}

/**
 * Log environment configuration in development
 */
if (config.isDevelopment && config.debug) {
  console.log('Environment Configuration:', {
    apiUrl: config.apiUrl,
    apiBaseUrl: getApiBaseUrl(),
    isDevelopment: config.isDevelopment,
    isProduction: config.isProduction,
    appName: config.appName,
    appVersion: config.appVersion,
  });
}

export default config;
