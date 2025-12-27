import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    // Test environment
    environment: 'jsdom',

    // Setup files
    setupFiles: ['./src/setupTests.ts'],

    // Global test utilities
    globals: true,

    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov', 'json-summary'],
      reportsDirectory: './coverage',

      // Files to include in coverage
      include: [
        'src/**/*.{ts,tsx}',
      ],

      // Files to exclude from coverage
      exclude: [
        'src/**/*.d.ts',
        'src/main.tsx',
        'src/vite-env.d.ts',
        'src/**/*.stories.{ts,tsx}',
        'src/__tests__/**',
        'src/__mocks__/**',
        'node_modules/**',
        'dist/**',
        'build/**',
      ],

      // Coverage thresholds - aim for 80%
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80,
      },

      // Fail if coverage is below threshold
      all: true,
    },

    // Test patterns
    include: [
      '**/__tests__/**/*.{test,spec}.{ts,tsx}',
      '**/*.{test,spec}.{ts,tsx}',
    ],

    // Files to exclude
    exclude: [
      'node_modules/**',
      'dist/**',
      'build/**',
      '.{idea,git,cache,output,temp}/**',
    ],

    // Clear mocks between tests
    clearMocks: true,
    mockReset: true,
    restoreMocks: true,

    // Test timeout
    testTimeout: 10000,

    // Reporters
    reporters: ['verbose', 'html'],

    // Output
    outputFile: {
      html: './coverage/index.html',
    },
  },

  // Resolve aliases
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
