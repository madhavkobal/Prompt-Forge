import React, { useState } from 'react';
import './Tutorial.css';

interface TutorialStep {
  id: string;
  title: string;
  description: string;
  icon: string;
  example?: string;
  tips?: string[];
}

const tutorialSteps: TutorialStep[] = [
  {
    id: 'basics',
    title: 'Prompt Engineering Basics',
    description: 'Learn the fundamentals of writing effective prompts for AI language models.',
    icon: '📚',
    example: `Write a blog post about sustainable living.

Target Audience: Young professionals aged 25-35
Tone: Informative yet conversational
Word Count: 800-1000 words

Include:
1. Introduction with statistics
2. 5 practical tips
3. Real-life examples
4. Conclusion with call-to-action`,
    tips: [
      'Be specific about your goals',
      'Provide context and background',
      'Specify the target audience',
      'Define the desired tone and style'
    ]
  },
  {
    id: 'structure',
    title: 'Structuring Your Prompts',
    description: 'Organize your prompts for clarity and better results.',
    icon: '📐',
    example: `[ROLE]
You are an experienced technical writer.

[TASK]
Create documentation for a REST API endpoint.

[CONTEXT]
Endpoint: POST /api/users
Purpose: Create new user account

[FORMAT]
Include: description, parameters, response codes, examples

[CONSTRAINTS]
- Use OpenAPI 3.0 specification
- Include security considerations
- Add code examples in Python and JavaScript`,
    tips: [
      'Use clear sections (Role, Task, Context, Format)',
      'Separate different types of information',
      'Use numbered lists for sequential steps',
      'Use bullet points for options or features'
    ]
  },
  {
    id: 'specificity',
    title: 'Being Specific',
    description: 'The more specific you are, the better results you\'ll get.',
    icon: '🎯',
    example: `❌ Bad: Write about marketing

✅ Good: Write a 500-word guide on email marketing strategies for B2B SaaS startups, focusing on:
- Subject line best practices
- Personalization techniques
- A/B testing methods
- Optimal send times
Target: Marketing managers with 1-3 years experience`,
    tips: [
      'Add concrete numbers and metrics',
      'Include specific examples',
      'Define exact requirements',
      'Specify output length and format',
      'Mention target audience demographics'
    ]
  },
  {
    id: 'examples',
    title: 'Using Examples',
    description: 'Show the AI what you want by providing examples.',
    icon: '💡',
    example: `Create product descriptions in this style:

Example 1:
"Introducing CloudFlow Pro - your command center for cloud infrastructure. Deploy faster, scale smarter, monitor everything. Built for teams who ship at lightspeed."

Example 2:
"MindfulBreak - the meditation app that respects your time. 5-minute sessions, zero fluff, real results. Perfect for busy professionals."

Now create a similar description for: [Your Product]`,
    tips: [
      'Provide 2-3 examples when possible',
      'Show different variations',
      'Highlight the style you want to match',
      'Include counter-examples (what NOT to do) if helpful'
    ]
  },
  {
    id: 'iteration',
    title: 'Iterative Improvement',
    description: 'Use analysis and enhancement to continuously improve your prompts.',
    icon: '🔄',
    example: `Step 1: Create initial prompt
→ Run analysis to see quality scores

Step 2: Review suggestions
→ Identify weaknesses (missing context, vague instructions)

Step 3: Enhance the prompt
→ Use AI enhancement or apply suggestions manually

Step 4: Re-analyze
→ Compare before/after scores
→ Iterate until you reach 85+ quality score`,
    tips: [
      'Start simple, then add details',
      'Analyze before and after changes',
      'Track what improvements work',
      'Build a library of successful prompts',
      'Learn from high-scoring prompts'
    ]
  },
  {
    id: 'templates',
    title: 'Using Templates',
    description: 'Save time by creating reusable templates for common tasks.',
    icon: '📋',
    example: `Template: Social Media Post

Create a {platform} post about {topic}.

Target Audience: {audience}
Tone: {tone}
Goal: {goal}

Include:
- Hook (first line)
- Value proposition
- Call-to-action
- {num_hashtags} relevant hashtags

Character limit: {char_limit}

---

Fill in the placeholders:
{platform} = Instagram
{topic} = New product launch
{audience} = Tech-savvy millennials
... and so on`,
    tips: [
      'Use {placeholders} for variable parts',
      'Create templates for repetitive tasks',
      'Share successful templates publicly',
      'Organize templates by category',
      'Include usage instructions in descriptions'
    ]
  }
];

interface TutorialProps {
  onComplete?: () => void;
  onClose?: () => void;
}

const Tutorial: React.FC<TutorialProps> = ({ onComplete, onClose }) => {
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [completedSteps, setCompletedSteps] = useState<Set<string>>(new Set());

  const currentStep = tutorialSteps[currentStepIndex];
  const isLastStep = currentStepIndex === tutorialSteps.length - 1;

  const handleNext = () => {
    // Mark current step as completed
    setCompletedSteps(prev => new Set(prev).add(currentStep.id));

    if (isLastStep) {
      if (onComplete) {
        onComplete();
      }
    } else {
      setCurrentStepIndex(currentStepIndex + 1);
    }
  };

  const handlePrev = () => {
    if (currentStepIndex > 0) {
      setCurrentStepIndex(currentStepIndex - 1);
    }
  };

  const handleStepClick = (index: number) => {
    setCurrentStepIndex(index);
  };

  const handleClose = () => {
    if (onClose) {
      onClose();
    }
  };

  const progressPercentage = ((currentStepIndex + 1) / tutorialSteps.length) * 100;

  return (
    <div className="tutorial-overlay">
      <div className="tutorial-container">
        {/* Header */}
        <div className="tutorial-header">
          <h2 className="tutorial-main-title">🎓 PromptForge Tutorial</h2>
          <button className="tutorial-close-btn" onClick={handleClose}>
            ✕
          </button>
        </div>

        {/* Progress bar */}
        <div className="tutorial-progress-section">
          <div className="tutorial-progress-bar">
            <div
              className="tutorial-progress-fill"
              style={{ width: `${progressPercentage}%` }}
            />
          </div>
          <span className="tutorial-progress-text">
            {currentStepIndex + 1} of {tutorialSteps.length} lessons
          </span>
        </div>

        {/* Main content area */}
        <div className="tutorial-content-wrapper">
          {/* Step navigation sidebar */}
          <div className="tutorial-sidebar">
            <h3 className="tutorial-sidebar-title">Lessons</h3>
            <div className="tutorial-steps-list">
              {tutorialSteps.map((step, index) => (
                <button
                  key={step.id}
                  className={`tutorial-step-item ${
                    index === currentStepIndex ? 'active' : ''
                  } ${completedSteps.has(step.id) ? 'completed' : ''}`}
                  onClick={() => handleStepClick(index)}
                >
                  <span className="tutorial-step-icon">{step.icon}</span>
                  <span className="tutorial-step-title">{step.title}</span>
                  {completedSteps.has(step.id) && (
                    <span className="tutorial-check-icon">✓</span>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Step content */}
          <div className="tutorial-main-content">
            <div className="tutorial-step-header">
              <span className="tutorial-step-icon-large">{currentStep.icon}</span>
              <div>
                <h2 className="tutorial-step-title">{currentStep.title}</h2>
                <p className="tutorial-step-description">{currentStep.description}</p>
              </div>
            </div>

            {/* Example */}
            {currentStep.example && (
              <div className="tutorial-section">
                <h3 className="tutorial-section-title">📝 Example</h3>
                <pre className="tutorial-example-box">{currentStep.example}</pre>
              </div>
            )}

            {/* Tips */}
            {currentStep.tips && currentStep.tips.length > 0 && (
              <div className="tutorial-section">
                <h3 className="tutorial-section-title">💡 Key Tips</h3>
                <ul className="tutorial-tips-list">
                  {currentStep.tips.map((tip, index) => (
                    <li key={index} className="tutorial-tip-item">
                      {tip}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        </div>

        {/* Navigation footer */}
        <div className="tutorial-footer">
          <button
            className="tutorial-btn tutorial-btn-secondary"
            onClick={handlePrev}
            disabled={currentStepIndex === 0}
          >
            ← Previous
          </button>

          <button
            className="tutorial-btn tutorial-btn-primary"
            onClick={handleNext}
          >
            {isLastStep ? 'Complete Tutorial 🎉' : 'Next Lesson →'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default Tutorial;
