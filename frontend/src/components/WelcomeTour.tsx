import React, { useState, useEffect } from 'react';
import './WelcomeTour.css';

interface TourStep {
  target: string;
  title: string;
  content: string;
  position?: 'top' | 'bottom' | 'left' | 'right';
}

const tourSteps: TourStep[] = [
  {
    target: 'body',
    title: '👋 Welcome to PromptForge!',
    content: 'Let\'s take a quick tour to help you get started with AI-powered prompt engineering.',
    position: 'bottom'
  },
  {
    target: '[data-tour="new-prompt"]',
    title: '✨ Create Your First Prompt',
    content: 'Click here to create a new prompt. You can write prompts for ChatGPT, Claude, Gemini, or any LLM.',
    position: 'bottom'
  },
  {
    target: '[data-tour="analyze"]',
    title: '🔍 Analyze Quality',
    content: 'After creating a prompt, use our AI-powered analysis to get quality scores and improvement suggestions.',
    position: 'left'
  },
  {
    target: '[data-tour="enhance"]',
    title: '🚀 Enhance Prompts',
    content: 'Automatically improve your prompts with AI. Get multiple enhanced versions to choose from.',
    position: 'left'
  },
  {
    target: '[data-tour="templates"]',
    title: '📋 Use Templates',
    content: 'Browse our template library for common use cases. Create reusable templates for your workflows.',
    position: 'bottom'
  },
  {
    target: '[data-tour="prompts"]',
    title: '📝 Manage Prompts',
    content: 'View all your prompts, track versions, and see quality improvements over time.',
    position: 'bottom'
  }
];

interface WelcomeTourProps {
  onComplete?: () => void;
  onSkip?: () => void;
}

const WelcomeTour: React.FC<WelcomeTourProps> = ({ onComplete, onSkip }) => {
  const [currentStep, setCurrentStep] = useState(0);
  const [isVisible, setIsVisible] = useState(true);
  const [tooltipPosition, setTooltipPosition] = useState({ top: 0, left: 0 });

  const step = tourSteps[currentStep];
  const isLastStep = currentStep === tourSteps.length - 1;
  const isFirstStep = currentStep === 0;

  useEffect(() => {
    // Calculate tooltip position based on target element
    const updatePosition = () => {
      if (!step.target || step.target === 'body') {
        // Center the tooltip for body target
        setTooltipPosition({
          top: window.innerHeight / 2 - 150,
          left: window.innerWidth / 2 - 200
        });
        return;
      }

      const targetElement = document.querySelector(step.target);
      if (targetElement) {
        const rect = targetElement.getBoundingClientRect();
        const position = step.position || 'bottom';

        let top = 0;
        let left = 0;

        switch (position) {
          case 'top':
            top = rect.top - 180;
            left = rect.left + rect.width / 2 - 200;
            break;
          case 'bottom':
            top = rect.bottom + 20;
            left = rect.left + rect.width / 2 - 200;
            break;
          case 'left':
            top = rect.top + rect.height / 2 - 75;
            left = rect.left - 420;
            break;
          case 'right':
            top = rect.top + rect.height / 2 - 75;
            left = rect.right + 20;
            break;
        }

        // Ensure tooltip stays within viewport
        top = Math.max(10, Math.min(top, window.innerHeight - 180));
        left = Math.max(10, Math.min(left, window.innerWidth - 410));

        setTooltipPosition({ top, left });

        // Highlight the target element
        targetElement.classList.add('tour-highlight');
      }
    };

    updatePosition();
    window.addEventListener('resize', updatePosition);

    return () => {
      window.removeEventListener('resize', updatePosition);
      // Remove highlight from all elements
      document.querySelectorAll('.tour-highlight').forEach(el => {
        el.classList.remove('tour-highlight');
      });
    };
  }, [currentStep, step]);

  const handleNext = () => {
    if (isLastStep) {
      handleComplete();
    } else {
      setCurrentStep(currentStep + 1);
    }
  };

  const handlePrev = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleSkip = () => {
    setIsVisible(false);
    if (onSkip) {
      onSkip();
    }
  };

  const handleComplete = () => {
    setIsVisible(false);
    if (onComplete) {
      onComplete();
    }
  };

  if (!isVisible) {
    return null;
  }

  return (
    <>
      {/* Backdrop overlay */}
      <div className="tour-backdrop" onClick={handleSkip} />

      {/* Tour tooltip */}
      <div
        className="tour-tooltip"
        style={{
          top: `${tooltipPosition.top}px`,
          left: `${tooltipPosition.left}px`
        }}
      >
        {/* Progress indicator */}
        <div className="tour-progress">
          <div className="tour-progress-bar">
            <div
              className="tour-progress-fill"
              style={{ width: `${((currentStep + 1) / tourSteps.length) * 100}%` }}
            />
          </div>
          <span className="tour-step-counter">
            Step {currentStep + 1} of {tourSteps.length}
          </span>
        </div>

        {/* Content */}
        <div className="tour-content">
          <h3 className="tour-title">{step.title}</h3>
          <p className="tour-description">{step.content}</p>
        </div>

        {/* Navigation */}
        <div className="tour-nav">
          <button
            className="tour-btn tour-btn-skip"
            onClick={handleSkip}
          >
            Skip Tour
          </button>

          <div className="tour-nav-buttons">
            {!isFirstStep && (
              <button
                className="tour-btn tour-btn-prev"
                onClick={handlePrev}
              >
                ← Previous
              </button>
            )}
            <button
              className="tour-btn tour-btn-next"
              onClick={handleNext}
            >
              {isLastStep ? 'Get Started! 🎉' : 'Next →'}
            </button>
          </div>
        </div>
      </div>
    </>
  );
};

export default WelcomeTour;
