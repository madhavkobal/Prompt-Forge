import Editor from '@monaco-editor/react';
import { Loader } from 'lucide-react';

interface PromptEditorProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  height?: string;
  readOnly?: boolean;
}

export default function PromptEditor({
  value,
  onChange,
  placeholder = 'Enter your prompt here...',
  height = '400px',
  readOnly = false,
}: PromptEditorProps) {
  const handleEditorChange = (value: string | undefined) => {
    onChange(value || '');
  };

  return (
    <div className="border border-gray-300 rounded-lg overflow-hidden">
      <Editor
        height={height}
        defaultLanguage="markdown"
        value={value}
        onChange={handleEditorChange}
        theme="vs-light"
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
        <div className="absolute top-20 left-6 text-gray-400 pointer-events-none">
          {placeholder}
        </div>
      )}
    </div>
  );
}
