/**
 * Frontend Performance Monitoring with Web Vitals
 *
 * Tracks Core Web Vitals and sends metrics to backend for monitoring
 * - LCP (Largest Contentful Paint)
 * - FID (First Input Delay)
 * - CLS (Cumulative Layout Shift)
 * - FCP (First Contentful Paint)
 * - TTFB (Time to First Byte)
 */

import { onCLS, onFID, onFCP, onLCP, onTTFB } from 'web-vitals';
import type { Metric } from 'web-vitals';
import { config } from '@/config/env';

interface PerformanceMetric {
  name: string;
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  timestamp: number;
  url: string;
  userAgent: string;
}

// Thresholds for Web Vitals (in milliseconds, except CLS which is unitless)
const THRESHOLDS = {
  LCP: { good: 2500, poor: 4000 },    // Largest Contentful Paint
  FID: { good: 100, poor: 300 },       // First Input Delay
  CLS: { good: 0.1, poor: 0.25 },      // Cumulative Layout Shift
  FCP: { good: 1800, poor: 3000 },     // First Contentful Paint
  TTFB: { good: 800, poor: 1800 },     // Time to First Byte
};

/**
 * Determine rating based on metric value and thresholds
 */
function getRating(name: string, value: number): 'good' | 'needs-improvement' | 'poor' {
  const threshold = THRESHOLDS[name as keyof typeof THRESHOLDS];
  if (!threshold) return 'good';

  if (value <= threshold.good) return 'good';
  if (value <= threshold.poor) return 'needs-improvement';
  return 'poor';
}

/**
 * Send metric to backend analytics endpoint
 */
async function sendMetricToBackend(metric: PerformanceMetric): Promise<void> {
  if (!config.isProduction) {
    // In development, log to console
    console.log('📊 Web Vital:', metric);
    return;
  }

  try {
    // Send to backend analytics endpoint
    await fetch(`${config.apiUrl}/api/v1/analytics/web-vitals`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(metric),
      // Use keepalive to ensure metric is sent even if page is closing
      keepalive: true,
    });
  } catch (error) {
    // Silently fail - don't block user experience for analytics
    if (config.debug) {
      console.error('Failed to send performance metric:', error);
    }
  }
}

/**
 * Handle Web Vital metric
 */
function handleMetric(metric: Metric): void {
  const performanceMetric: PerformanceMetric = {
    name: metric.name,
    value: metric.value,
    rating: getRating(metric.name, metric.value),
    timestamp: Date.now(),
    url: window.location.pathname,
    userAgent: navigator.userAgent,
  };

  // Send to backend
  sendMetricToBackend(performanceMetric);

  // Log warning for poor performance in development
  if (!config.isProduction && performanceMetric.rating === 'poor') {
    console.warn(`⚠️ Poor ${metric.name}: ${metric.value.toFixed(2)}`);
  }
}

/**
 * Initialize Web Vitals monitoring
 * Call this once when the app starts
 */
export function initializePerformanceMonitoring(): void {
  // Only track in browser environment
  if (typeof window === 'undefined') return;

  // Track Core Web Vitals
  onLCP(handleMetric);  // Largest Contentful Paint
  onFID(handleMetric);  // First Input Delay
  onCLS(handleMetric);  // Cumulative Layout Shift
  onFCP(handleMetric);  // First Contentful Paint
  onTTFB(handleMetric); // Time to First Byte

  if (config.debug) {
    console.log('✅ Performance monitoring initialized');
  }
}

/**
 * Track custom performance marks
 */
export function trackPerformanceMark(name: string): void {
  if (typeof window === 'undefined' || !window.performance) return;

  try {
    performance.mark(name);
  } catch (error) {
    console.error('Failed to create performance mark:', error);
  }
}

/**
 * Measure custom performance between two marks
 */
export function measurePerformance(name: string, startMark: string, endMark: string): number | null {
  if (typeof window === 'undefined' || !window.performance) return null;

  try {
    performance.measure(name, startMark, endMark);
    const measure = performance.getEntriesByName(name, 'measure')[0];
    return measure?.duration || null;
  } catch (error) {
    console.error('Failed to measure performance:', error);
    return null;
  }
}

/**
 * Track page navigation timing
 */
export function trackPageLoad(): void {
  if (typeof window === 'undefined' || !window.performance) return;

  // Wait for page load to complete
  window.addEventListener('load', () => {
    setTimeout(() => {
      const perfData = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;

      if (perfData) {
        const pageLoadMetrics = {
          dns: perfData.domainLookupEnd - perfData.domainLookupStart,
          tcp: perfData.connectEnd - perfData.connectStart,
          request: perfData.responseStart - perfData.requestStart,
          response: perfData.responseEnd - perfData.responseStart,
          domProcessing: perfData.domComplete - perfData.domInteractive,
          domContentLoaded: perfData.domContentLoadedEventEnd - perfData.domContentLoadedEventStart,
          loadComplete: perfData.loadEventEnd - perfData.loadEventStart,
          totalTime: perfData.loadEventEnd - perfData.fetchStart,
        };

        if (config.debug) {
          console.log('📈 Page Load Metrics:', pageLoadMetrics);
        }

        // Send to backend if in production
        if (config.isProduction) {
          sendMetricToBackend({
            name: 'PAGE_LOAD',
            value: pageLoadMetrics.totalTime,
            rating: getRating('LCP', pageLoadMetrics.totalTime),
            timestamp: Date.now(),
            url: window.location.pathname,
            userAgent: navigator.userAgent,
          });
        }
      }
    }, 0);
  });
}

/**
 * Track SPA route changes
 */
export function trackRouteChange(route: string): void {
  if (!config.isProduction) {
    console.log('🔄 Route change:', route);
    return;
  }

  // Send route change event to analytics
  sendMetricToBackend({
    name: 'ROUTE_CHANGE',
    value: Date.now(),
    rating: 'good',
    timestamp: Date.now(),
    url: route,
    userAgent: navigator.userAgent,
  });
}

/**
 * Get performance report for debugging
 */
export function getPerformanceReport(): void {
  if (typeof window === 'undefined' || !window.performance) {
    console.log('Performance API not available');
    return;
  }

  const perfData = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;

  if (perfData) {
    const report = {
      'DNS Lookup': `${(perfData.domainLookupEnd - perfData.domainLookupStart).toFixed(2)}ms`,
      'TCP Connection': `${(perfData.connectEnd - perfData.connectStart).toFixed(2)}ms`,
      'Request Time': `${(perfData.responseStart - perfData.requestStart).toFixed(2)}ms`,
      'Response Time': `${(perfData.responseEnd - perfData.responseStart).toFixed(2)}ms`,
      'DOM Processing': `${(perfData.domComplete - perfData.domInteractive).toFixed(2)}ms`,
      'Load Event': `${(perfData.loadEventEnd - perfData.loadEventStart).toFixed(2)}ms`,
      'Total Time': `${(perfData.loadEventEnd - perfData.fetchStart).toFixed(2)}ms`,
    };

    console.table(report);
  }
}

// Export for use in browser console
if (typeof window !== 'undefined') {
  (window as any).getPerformanceReport = getPerformanceReport;
}
