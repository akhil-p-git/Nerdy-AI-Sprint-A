import type { CSSProperties } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import type { Message } from '../../types/chat';
import { HandoffSuggestion } from './HandoffSuggestion';

interface MessageBubbleProps {
  message: Message;
  isStreaming?: boolean;
}

export function MessageBubble({ message, isStreaming }: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const isHandoff = message.metadata?.type === 'handoff_suggestion';

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-[80%] rounded-2xl px-4 py-3 ${
          isUser
            ? 'bg-indigo-600 text-white'
            : 'bg-white border border-gray-200 text-gray-800'
        } ${isStreaming ? 'animate-pulse' : ''}`}
      >
        {isHandoff ? (
          <HandoffSuggestion context={message.metadata?.context} />
        ) : (
          <div className={`prose prose-sm max-w-none ${isUser ? 'prose-invert' : ''}`}>
            <ReactMarkdown
              remarkPlugins={[remarkGfm, remarkMath]}
              rehypePlugins={[rehypeKatex]}
              components={{
                code({ className, children, ...props }) {
                  const match = /language-(\w+)/.exec(className || '');
                  const isCodeBlock = match !== null;
                  return isCodeBlock ? (
                    <SyntaxHighlighter
                      style={oneDark as Record<string, CSSProperties>}
                      language={match[1]}
                      PreTag="div"
                      className="rounded-lg text-sm"
                    >
                      {String(children).replace(/\n$/, '')}
                    </SyntaxHighlighter>
                  ) : (
                    <code
                      className={`${
                        isUser ? 'bg-indigo-500' : 'bg-gray-100'
                      } px-1 py-0.5 rounded text-sm`}
                      {...props}
                    >
                      {children}
                    </code>
                  );
                },
                p({ children }) {
                  return <p className="mb-2 last:mb-0">{children}</p>;
                },
                ul({ children }) {
                  return <ul className="list-disc pl-4 mb-2">{children}</ul>;
                },
                ol({ children }) {
                  return <ol className="list-decimal pl-4 mb-2">{children}</ol>;
                }
              }}
            >
              {message.content}
            </ReactMarkdown>
          </div>
        )}

        {/* Timestamp */}
        <div
          className={`text-xs mt-2 ${
            isUser ? 'text-indigo-200' : 'text-gray-400'
          }`}
        >
          {new Date(message.created_at).toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit'
          })}
        </div>
      </div>
    </div>
  );
}


