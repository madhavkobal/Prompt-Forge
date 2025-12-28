import React, { useState, useEffect } from 'react';
import './DemoMode.css';

interface DemoModeProps {
  onTryDemo?: () => void;
  onSignUp?: () => void;
  onLearnMore?: () => void;
}

const DemoMode: React.FC<DemoModeProps> = ({ onTryDemo, onSignUp, onLearnMore }) => {
  const [currentFeature, setCurrentFeature] = useState(0);

  const features = [
    {
      icon: '🔍',
      title: 'AI-Powered Analysis',
      description: 'Get comprehensive quality scores and detailed feedback on your prompts',
      stats: '4 scoring dimensions',
      color: '#3b82f6'
    },
    {
      icon: '✨',
      title: 'Automatic Enhancement',
      description: 'Improve your prompts instantly with AI-powered suggestions and variations',
      stats: 'Up to 3 enhanced versions',
      color: '#8b5cf6'
    },
    {
      icon: '📋',
      title: 'Template Library',
      description: 'Access dozens of professional templates for every use case',
      stats: '50+ templates',
      color: '#10b981'
    },
    {
      icon: '📊',
      title: 'Version Control',
      description: 'Track improvements over time and compare different prompt versions',
      stats: 'Unlimited versions',
      color: '#f59e0b'
    }
  ];

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentFeature((prev) => (prev + 1) % features.length);
    }, 4000);

    return () => clearInterval(interval);
  }, [features.length]);

  const feature = features[currentFeature];

  return (
    <div className="demo-mode-container">
      {/* Hero section */}
      <div className="demo-hero">
        <div className="demo-hero-badge">
          <span className="demo-badge-dot"></span>
          Public Demo Mode
        </div>

        <h1 className="demo-hero-title">
          Master the Art of
          <br />
          <span className="demo-hero-gradient">Prompt Engineering</span>
        </h1>

        <p className="demo-hero-subtitle">
          PromptForge helps you create, analyze, and enhance prompts for ChatGPT, Claude, Gemini, and any LLM.
          Get instant feedback and AI-powered improvements.
        </p>

        <div className="demo-hero-actions">
          <button className="demo-btn demo-btn-primary demo-btn-large" onClick={onTryDemo}>
            Try Demo Now →
          </button>
          <button className="demo-btn demo-btn-secondary demo-btn-large" onClick={onSignUp}>
            Create Free Account
          </button>
        </div>

        <div className="demo-hero-stats">
          <div className="demo-stat">
            <div className="demo-stat-value">10K+</div>
            <div className="demo-stat-label">Prompts Analyzed</div>
          </div>
          <div className="demo-stat">
            <div className="demo-stat-value">85%</div>
            <div className="demo-stat-label">Avg. Quality Improvement</div>
          </div>
          <div className="demo-stat">
            <div className="demo-stat-value">50+</div>
            <div className="demo-stat-label">Ready-to-Use Templates</div>
          </div>
        </div>
      </div>

      {/* Feature showcase */}
      <div className="demo-features-section">
        <h2 className="demo-section-title">Why Choose PromptForge?</h2>

        <div className="demo-feature-carousel">
          <div className="demo-feature-main" style={{ borderColor: feature.color }}>
            <div className="demo-feature-icon" style={{ background: `${feature.color}20`, color: feature.color }}>
              {feature.icon}
            </div>
            <h3 className="demo-feature-title">{feature.title}</h3>
            <p className="demo-feature-description">{feature.description}</p>
            <div className="demo-feature-stat" style={{ color: feature.color }}>
              {feature.stats}
            </div>
          </div>

          <div className="demo-feature-dots">
            {features.map((_, index) => (
              <button
                key={index}
                className={`demo-dot ${index === currentFeature ? 'active' : ''}`}
                onClick={() => setCurrentFeature(index)}
                style={{ background: index === currentFeature ? feature.color : undefined }}
              />
            ))}
          </div>
        </div>
      </div>

      {/* How it works */}
      <div className="demo-how-section">
        <h2 className="demo-section-title">How It Works</h2>

        <div className="demo-steps">
          <div className="demo-step">
            <div className="demo-step-number">1</div>
            <div className="demo-step-icon">✍️</div>
            <h3 className="demo-step-title">Write Your Prompt</h3>
            <p className="demo-step-description">
              Create a prompt for any task - blog posts, code, emails, or use our templates
            </p>
          </div>

          <div className="demo-step-arrow">→</div>

          <div className="demo-step">
            <div className="demo-step-number">2</div>
            <div className="demo-step-icon">🔍</div>
            <h3 className="demo-step-title">Get AI Analysis</h3>
            <p className="demo-step-description">
              Receive detailed quality scores, suggestions, and best practice recommendations
            </p>
          </div>

          <div className="demo-step-arrow">→</div>

          <div className="demo-step">
            <div className="demo-step-number">3</div>
            <div className="demo-step-icon">✨</div>
            <h3 className="demo-step-title">Enhance & Iterate</h3>
            <p className="demo-step-description">
              Automatically improve your prompt or apply suggestions manually
            </p>
          </div>

          <div className="demo-step-arrow">→</div>

          <div className="demo-step">
            <div className="demo-step-number">4</div>
            <div className="demo-step-icon">🚀</div>
            <h3 className="demo-step-title">Get Better Results</h3>
            <p className="demo-step-description">
              Use your optimized prompt with any LLM for superior outcomes
            </p>
          </div>
        </div>
      </div>

      {/* CTA section */}
      <div className="demo-cta-section">
        <div className="demo-cta-content">
          <h2 className="demo-cta-title">Ready to Create Better Prompts?</h2>
          <p className="demo-cta-subtitle">
            Join thousands of users improving their AI interactions
          </p>
          <div className="demo-cta-actions">
            <button className="demo-btn demo-btn-primary demo-btn-large" onClick={onTryDemo}>
              Try Demo Now - No Login Required
            </button>
          </div>
          <p className="demo-cta-note">
            Or <button className="demo-link-btn" onClick={onSignUp}>create a free account</button> to save your prompts
          </p>
        </div>
      </div>

      {/* Features grid */}
      <div className="demo-features-grid-section">
        <h2 className="demo-section-title">Everything You Need</h2>

        <div className="demo-features-grid">
          <div className="demo-feature-card">
            <div className="demo-feature-card-icon">📝</div>
            <h3 className="demo-feature-card-title">Prompt Editor</h3>
            <p className="demo-feature-card-text">
              Clean, distraction-free interface with syntax highlighting and auto-save
            </p>
          </div>

          <div className="demo-feature-card">
            <div className="demo-feature-card-icon">🎯</div>
            <h3 className="demo-feature-card-title">Quality Metrics</h3>
            <p className="demo-feature-card-text">
              4 scoring dimensions: Clarity, Specificity, Structure, and Best Practices
            </p>
          </div>

          <div className="demo-feature-card">
            <div className="demo-feature-card-icon">💡</div>
            <h3 className="demo-feature-card-title">Smart Suggestions</h3>
            <p className="demo-feature-card-text">
              Actionable recommendations to improve every aspect of your prompts
            </p>
          </div>

          <div className="demo-feature-card">
            <div className="demo-feature-card-icon">🔄</div>
            <h3 className="demo-feature-card-title">Multi-Variant Enhancement</h3>
            <p className="demo-feature-card-text">
              Generate 3 different enhanced versions to choose from
            </p>
          </div>

          <div className="demo-feature-card">
            <div className="demo-feature-card-icon">📚</div>
            <h3 className="demo-feature-card-title">Template Library</h3>
            <p className="demo-feature-card-text">
              Professional templates for content, code, marketing, and more
            </p>
          </div>

          <div className="demo-feature-card">
            <div className="demo-feature-card-icon">📊</div>
            <h3 className="demo-feature-card-title">Version History</h3>
            <p className="demo-feature-card-text">
              Track all changes and improvements over time
            </p>
          </div>

          <div className="demo-feature-card">
            <div className="demo-feature-card-icon">🔐</div>
            <h3 className="demo-feature-card-title">Secure & Private</h3>
            <p className="demo-feature-card-text">
              Your prompts are encrypted and never used for training
            </p>
          </div>

          <div className="demo-feature-card">
            <div className="demo-feature-card-icon">⚡</div>
            <h3 className="demo-feature-card-title">Fast & Reliable</h3>
            <p className="demo-feature-card-text">
              Analysis in 3-5 seconds, 99.9% uptime, instant results
            </p>
          </div>
        </div>
      </div>

      {/* FAQ preview */}
      <div className="demo-faq-section">
        <h2 className="demo-section-title">Frequently Asked Questions</h2>

        <div className="demo-faq-list">
          <details className="demo-faq-item">
            <summary className="demo-faq-question">
              What is prompt engineering?
            </summary>
            <p className="demo-faq-answer">
              Prompt engineering is the practice of crafting effective instructions for AI language models like ChatGPT, Claude, or Gemini. Well-engineered prompts produce better, more accurate, and more useful responses from AI.
            </p>
          </details>

          <details className="demo-faq-item">
            <summary className="demo-faq-question">
              Do I need an account to try the demo?
            </summary>
            <p className="demo-faq-answer">
              No! You can try PromptForge in demo mode without creating an account. However, creating a free account allows you to save your prompts, access templates, and track your improvements over time.
            </p>
          </details>

          <details className="demo-faq-item">
            <summary className="demo-faq-question">
              Which AI models does PromptForge support?
            </summary>
            <p className="demo-faq-answer">
              PromptForge works with all major LLMs including ChatGPT (GPT-3.5, GPT-4), Claude (Anthropic), Google Gemini, and any other language model. Our analysis adapts to your target LLM.
            </p>
          </details>

          <details className="demo-faq-item">
            <summary className="demo-faq-question">
              How does the AI analysis work?
            </summary>
            <p className="demo-faq-answer">
              We use Google Gemini AI to analyze your prompts across four dimensions: Clarity, Specificity, Structure, and Best Practices. The analysis provides scores (0-100), identifies strengths and weaknesses, and offers specific improvement suggestions.
            </p>
          </details>
        </div>

        <button className="demo-btn demo-btn-secondary" onClick={onLearnMore}>
          View All FAQs →
        </button>
      </div>

      {/* Footer CTA */}
      <div className="demo-footer-cta">
        <h2 className="demo-footer-title">Start Improving Your Prompts Today</h2>
        <button className="demo-btn demo-btn-primary demo-btn-xl" onClick={onTryDemo}>
          Launch Demo →
        </button>
      </div>
    </div>
  );
};

export default DemoMode;
