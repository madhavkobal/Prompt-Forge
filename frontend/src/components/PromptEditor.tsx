import Editor from '@monaco-editor/react';
import { Loader } from 'lucide-react';
import { useState, useEffect } from 'react';

interface PromptEditorProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  height?: string;
  readOnly?: boolean;
  theme?: 'light' | 'dark' | 'auto';
}

export default function PromptEditor({
  value,
  onChange,
  placeholder = 'Enter your prompt here...',
  height = '400px',
  readOnly = false,
  theme = 'auto',
}: PromptEditorProps) {
  const [resolvedTheme, setResolvedTheme] = useState<'vs-light' | 'vs-dark'>('vs-light');

  useEffect(() => {
    if (theme === 'light') {
      setResolvedTheme('vs-light');
    } else if (theme === 'dark') {
      setResolvedTheme('vs-dark');
    } else {
      // Auto mode - detect system preference
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      setResolvedTheme(prefersDark ? 'vs-dark' : 'vs-light');

      // Listen for system theme changes
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const handleChange = (e: MediaQueryListEvent) => {
        setResolvedTheme(e.matches ? 'vs-dark' : 'vs-light');
      };

      mediaQuery.addEventListener('change', handleChange);
      return () => mediaQuery.removeEventListener('change', handleChange);
    }
  }, [theme]);

  const handleEditorChange = (value: string | undefined) => {
    onChange(value || '');
  };

  const isDark = resolvedTheme === 'vs-dark';
  const borderClass = isDark ? 'border-gray-700' : 'border-gray-300';
  const placeholderClass = isDark ? 'text-gray-500' : 'text-gray-400';

  return (
    <div className={`border ${borderClass} rounded-lg overflow-hidden`}>
      <Editor
        height={height}
        defaultLanguage="markdown"
        value={value}
        onChange={handleEditorChange}
        theme={resolvedTheme}
        loading={
          <div className="flex items-center justify-center h-full">
            <Loader className="animate-spin h-8 w-8 text-primary-600" />
          </div>
        }
        options={{
          minimap: { enabled: false },
          fontSize: 14,
          lineNumbers: 'on',
          wordWrap: 'on',
          scrollBeyondLastLine: false,
          automaticLayout: true,
          readOnly,
          padding: { top: 16, bottom: 16 },
          lineHeight: 24,
          fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
          renderWhitespace: 'selection',
          bracketPairColorization: {
            enabled: true,
          },
          suggest: {
            showWords: false,
          },
        }}
      />
      {!value && !readOnly && (
        <div className={`absolute top-20 left-6 ${placeholderClass} pointer-events-none`}>
          {placeholder}
        </div>
      )}
    </div>
  );
}
