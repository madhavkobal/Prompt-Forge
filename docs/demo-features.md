# Demo and Onboarding Features

Complete guide to PromptForge's demo data and onboarding system.

## Table of Contents

1. [Overview](#overview)
2. [Demo Data Seeding](#demo-data-seeding)
3. [Onboarding Components](#onboarding-components)
4. [Demo Mode](#demo-mode)
5. [Integration Guide](#integration-guide)

---

## Overview

PromptForge includes a comprehensive demo and onboarding system designed to:

- **Help new users** understand the platform quickly
- **Showcase features** without requiring sign-up
- **Provide sample data** for testing and demonstration
- **Guide users** through best practices

### Key Components

1. **Seed Script** - Populate database with demo data
2. **Welcome Tour** - Guided walkthrough for first-time users
3. **Interactive Tutorial** - Step-by-step prompt engineering lessons
4. **Sample Prompts** - Professional prompt templates to try
5. **Demo Mode** - Public showcase landing page

---

## Demo Data Seeding

### Seed Script

Located at: `backend/scripts/seed_data.py`

This script creates:
- Demo user account
- 7 sample templates covering different use cases
- 5 sample prompts with realistic analysis results
- Version history for select prompts

### Running the Seed Script

**Basic usage:**
```bash
cd backend
python scripts/seed_data.py
```

**Reset and recreate data:**
```bash
python scripts/seed_data.py --reset
```

### Demo Account Credentials

After running the seed script:

- **Username:** `demo`
- **Password:** `DemoPassword123!`
- **Email:** `demo@promptforge.io`

### Sample Templates Included

1. **Blog Post Generator**
   - Category: Content Creation
   - Use case: Creating comprehensive blog posts
   - Features: SEO optimization, structured sections

2. **Code Documentation**
   - Category: Development
   - Use case: Technical documentation
   - Features: Multiple documentation formats

3. **Product Description**
   - Category: Marketing
   - Use case: E-commerce product copy
   - Features: Conversion-focused structure

4. **Email Response**
   - Category: Communication
   - Use case: Professional customer service
   - Features: Multiple response types

5. **Data Analysis Request**
   - Category: Analytics
   - Use case: Comprehensive data analysis
   - Features: Statistical analysis, insights

6. **Social Media Post**
   - Category: Social Media
   - Use case: Platform-specific content
   - Features: Engagement mechanics

7. **Meeting Agenda**
   - Category: Business
   - Use case: Productive meetings
   - Features: Structured agenda format

### Sample Prompts Included

1. **High-Quality Blog Post** (Score: 92.5/100)
   - Demonstrates excellent prompt structure
   - Includes detailed analysis results
   - Shows best practices

2. **Medium-Quality Product Description** (Score: 65.0/100)
   - Shows room for improvement
   - Includes enhancement suggestions
   - Before/after example

3. **Poor-Quality Email Request** (Score: 35.0/100)
   - Demonstrates common mistakes
   - Extensive improvement suggestions
   - Learning opportunity

4. **Code Documentation** (Score: 88.0/100)
   - Technical documentation example
   - API documentation focus

5. **Social Media Content** (Score: 85.0/100)
   - Platform-specific optimization
   - Engagement strategies

---

## Onboarding Components

### 1. Welcome Tour

**File:** `frontend/src/components/WelcomeTour.tsx`

**Purpose:** Guided walkthrough for first-time users

**Features:**
- 6-step interactive tour
- Highlights key UI elements
- Progress indicator
- Skip and navigate options
- Responsive design

**Usage:**
```tsx
import { WelcomeTour } from '@/components';

function App() {
  const handleTourComplete = () => {
    localStorage.setItem('tourCompleted', 'true');
  };

  return (
    <>
      {!localStorage.getItem('tourCompleted') && (
        <WelcomeTour onComplete={handleTourComplete} />
      )}
      {/* Your app content */}
    </>
  );
}
```

**Tour Steps:**
1. Welcome message
2. Create new prompt
3. Analyze quality
4. Enhance prompts
5. Use templates
6. Manage prompts

**Data Attributes Required:**
- `data-tour="new-prompt"` - New prompt button
- `data-tour="analyze"` - Analyze button
- `data-tour="enhance"` - Enhance button
- `data-tour="templates"` - Templates link
- `data-tour="prompts"` - Prompts list link

### 2. Interactive Tutorial

**File:** `frontend/src/components/Tutorial.tsx`

**Purpose:** Teach prompt engineering best practices

**Features:**
- 6 comprehensive lessons
- Code examples for each lesson
- Key tips and best practices
- Progress tracking
- Completion tracking

**Usage:**
```tsx
import { Tutorial } from '@/components';

function App() {
  const [showTutorial, setShowTutorial] = useState(false);

  const handleTutorialComplete = () => {
    localStorage.setItem('tutorialCompleted', 'true');
    setShowTutorial(false);
  };

  return (
    <>
      <button onClick={() => setShowTutorial(true)}>
        Open Tutorial
      </button>

      {showTutorial && (
        <Tutorial
          onComplete={handleTutorialComplete}
          onClose={() => setShowTutorial(false)}
        />
      )}
    </>
  );
}
```

**Lessons Included:**
1. **Prompt Engineering Basics** - Fundamentals and core concepts
2. **Structuring Your Prompts** - Organization and clarity
3. **Being Specific** - Detail and precision
4. **Using Examples** - Few-shot prompting
5. **Iterative Improvement** - Analysis and enhancement cycle
6. **Using Templates** - Reusable patterns

### 3. Sample Prompts Browser

**File:** `frontend/src/components/DemoPrompts.tsx`

**Purpose:** Showcase professional prompt examples

**Features:**
- 6 sample prompts with real content
- Category filtering
- Quality score display
- Detailed view mode
- Copy to use functionality

**Usage:**
```tsx
import { DemoPrompts } from '@/components';

function App() {
  const handleUsePrompt = (prompt) => {
    // Navigate to editor with prompt content
    navigate('/prompts/new', { state: { content: prompt.content } });
  };

  return (
    <DemoPrompts
      onUsePrompt={handleUsePrompt}
      onClose={() => setShowDemo(false)}
    />
  );
}
```

**Sample Prompts:**
1. **Blog Post Generator** (92/100) - Content creation
2. **Code Review Assistant** (89/100) - Development
3. **Marketing Copy Generator** (87/100) - Marketing
4. **Data Analysis Request** (91/100) - Analytics
5. **Email Sequence Builder** (85/100) - Communication
6. **Social Media Calendar** (88/100) - Social media

### 4. Demo Mode Landing Page

**File:** `frontend/src/components/DemoMode.tsx`

**Purpose:** Public showcase without authentication

**Features:**
- Hero section with value proposition
- Rotating feature showcase
- How it works section
- Feature grid (8 key features)
- FAQ preview
- Multiple CTAs
- Fully responsive

**Usage:**
```tsx
import { DemoMode } from '@/components';

function LandingPage() {
  return (
    <DemoMode
      onTryDemo={() => navigate('/demo')}
      onSignUp={() => navigate('/signup')}
      onLearnMore={() => navigate('/docs')}
    />
  );
}
```

**Sections:**
1. **Hero** - Main value proposition and CTAs
2. **Stats** - Key metrics (10K+ prompts, 85% improvement)
3. **Feature Carousel** - Auto-rotating feature highlights
4. **How It Works** - 4-step process visualization
5. **CTA Section** - Mid-page conversion point
6. **Features Grid** - 8 feature cards
7. **FAQ Preview** - 4 common questions
8. **Footer CTA** - Final conversion point

---

## Demo Mode

### Public Demo Access

Demo mode allows users to try PromptForge without creating an account.

**Features available in demo mode:**
- Browse sample prompts
- View quality analysis
- See enhancement examples
- Explore templates
- Interactive tutorial

**Limitations in demo mode:**
- Cannot save prompts
- Cannot create new prompts (only try samples)
- Limited to sample data
- No version history access
- No personal templates

### Implementing Demo Mode

**1. Create demo route:**
```tsx
// In your router
<Route path="/demo" element={<DemoPage />} />
```

**2. Demo page component:**
```tsx
import { DemoPrompts, Tutorial } from '@/components';

function DemoPage() {
  const [view, setView] = useState<'prompts' | 'tutorial'>('prompts');

  return (
    <div className="demo-page">
      <header>
        <h1>Try PromptForge - No Login Required</h1>
        <button onClick={() => navigate('/signup')}>
          Create Free Account
        </button>
      </header>

      {view === 'prompts' ? (
        <DemoPrompts onUsePrompt={handleUsePrompt} />
      ) : (
        <Tutorial onComplete={() => setView('prompts')} />
      )}
    </div>
  );
}
```

**3. Restrict API calls:**
```typescript
// Use demo data instead of API calls
const analyzePrompt = async (content: string) => {
  if (isDemoMode) {
    return getDemoAnalysis(content);
  }
  return api.analyze(content);
};
```

---

## Integration Guide

### Complete Onboarding Flow

**1. First-time user lands on app:**
```tsx
function App() {
  const [showTour, setShowTour] = useState(false);
  const [showTutorial, setShowTutorial] = useState(false);

  useEffect(() => {
    const tourCompleted = localStorage.getItem('tourCompleted');
    if (!tourCompleted) {
      setShowTour(true);
    }
  }, []);

  const handleTourComplete = () => {
    localStorage.setItem('tourCompleted', 'true');
    setShowTour(false);
    // Optionally show tutorial next
    setTimeout(() => setShowTutorial(true), 500);
  };

  return (
    <>
      {showTour && <WelcomeTour onComplete={handleTourComplete} />}
      {showTutorial && <Tutorial onClose={() => setShowTutorial(false)} />}
      {/* App content */}
    </>
  );
}
```

**2. Add help menu:**
```tsx
function HelpMenu() {
  return (
    <DropdownMenu>
      <DropdownItem onClick={() => setShowTour(true)}>
        🎯 Restart Tour
      </DropdownItem>
      <DropdownItem onClick={() => setShowTutorial(true)}>
        📚 View Tutorial
      </DropdownItem>
      <DropdownItem onClick={() => setShowSamples(true)}>
        💡 Sample Prompts
      </DropdownItem>
      <DropdownItem onClick={() => navigate('/docs')}>
        📖 Documentation
      </DropdownItem>
    </DropdownMenu>
  );
}
```

**3. Onboarding progress tracking:**
```tsx
interface OnboardingProgress {
  tourCompleted: boolean;
  tutorialCompleted: boolean;
  firstPromptCreated: boolean;
  firstAnalysisRun: boolean;
  firstEnhancement: boolean;
}

const trackProgress = (action: string) => {
  const progress = getOnboardingProgress();
  progress[action] = true;
  saveOnboardingProgress(progress);

  // Show celebration or next step
  if (isOnboardingComplete(progress)) {
    showCompletionMessage();
  }
};
```

### Recommended User Journey

1. **Landing (Not logged in)**
   - Show DemoMode landing page
   - Offer "Try Demo" or "Sign Up"

2. **Demo Mode**
   - Show DemoPrompts browser
   - Allow exploration without signup
   - Encourage signup to save work

3. **First Login**
   - Trigger WelcomeTour automatically
   - Show 6-step guided tour
   - Mark completion in localStorage

4. **Post-Tour (Optional)**
   - Offer Tutorial modal
   - Can be skipped
   - Accessible later from help menu

5. **First Prompt Creation**
   - Provide DemoPrompts as examples
   - Show tooltips for key features
   - Track milestone

6. **Ongoing**
   - All onboarding features in help menu
   - Contextual tips on new features
   - Progress tracking

---

## Styling and Customization

### CSS Variables

All components use consistent color scheme:

```css
:root {
  --primary-gradient: linear-gradient(135deg, #3b82f6, #8b5cf6);
  --primary-blue: #3b82f6;
  --primary-purple: #8b5cf6;
  --success-green: #10b981;
  --warning-orange: #f59e0b;
  --error-red: #ef4444;
}
```

### Customizing Components

**Change tour steps:**
```tsx
// In WelcomeTour.tsx
const tourSteps: TourStep[] = [
  // Add, remove, or modify steps
  {
    target: '[data-tour="custom"]',
    title: 'Your Custom Step',
    content: 'Custom description',
    position: 'bottom'
  }
];
```

**Customize tutorial lessons:**
```tsx
// In Tutorial.tsx
const tutorialSteps: TutorialStep[] = [
  // Modify lessons, add examples, change tips
];
```

**Update demo prompts:**
```tsx
// In DemoPrompts.tsx
const demoPrompts: DemoPrompt[] = [
  // Add your own sample prompts
];
```

---

## Analytics and Tracking

### Track User Engagement

```tsx
// Track tour engagement
const handleTourComplete = () => {
  analytics.track('Tour Completed', {
    stepsCompleted: 6,
    timeSpent: calculateTime(),
  });
};

// Track tutorial progress
const handleLessonComplete = (lessonId: string) => {
  analytics.track('Lesson Completed', {
    lessonId,
    lessonNumber: currentStep,
  });
};

// Track demo prompt usage
const handleUsePrompt = (prompt: DemoPrompt) => {
  analytics.track('Demo Prompt Used', {
    promptId: prompt.id,
    category: prompt.category,
    qualityScore: prompt.qualityScore,
  });
};
```

### A/B Testing

```tsx
// Test different onboarding flows
const variant = getABTestVariant();

if (variant === 'A') {
  // Show tour immediately
  setShowTour(true);
} else {
  // Show demo prompts first
  setShowDemoPrompts(true);
}
```

---

## Best Practices

### When to Show Onboarding

**✅ Good Times:**
- First login (tour)
- After signup (optional tutorial)
- User clicks "Help" (all resources)
- User seems stuck (contextual prompts)

**❌ Avoid:**
- Every login (annoying)
- Mid-workflow (disruptive)
- Too many steps at once (overwhelming)

### Progressive Disclosure

Start with basics, reveal advanced features gradually:

1. **Tour** - Basic navigation (6 steps)
2. **First prompt** - Show editor features
3. **First analysis** - Explain scores
4. **Tutorial** - Deeper learning (optional)
5. **Advanced features** - Templates, versions (as discovered)

### Accessibility

All components include:
- Keyboard navigation
- ARIA labels
- Screen reader support
- High contrast mode compatible
- Focus management

---

## Troubleshooting

### Tour not appearing

**Check:**
- Data attributes are present on target elements
- Tour hasn't been marked complete in localStorage
- No z-index conflicts
- Component is mounted

**Fix:**
```tsx
// Reset tour
localStorage.removeItem('tourCompleted');
```

### Demo mode API calls failing

**Check:**
- Demo mode flag is set correctly
- Using demo data instead of API calls
- Error handling for network failures

**Fix:**
```tsx
const isDemoMode = !user || user.username === 'demo';

if (isDemoMode) {
  return getDemoData();
}
```

### Styling conflicts

**Check:**
- CSS import order
- Global styles overriding component styles
- Z-index stacking context

**Fix:**
```tsx
// Use CSS modules or scoped styles
import styles from './WelcomeTour.module.css';
```

---

## Future Enhancements

### Planned Features

1. **Personalized Onboarding**
   - Role-based tours (developer, marketer, writer)
   - Skip irrelevant sections
   - Custom learning paths

2. **Video Tutorials**
   - Screen recordings for each lesson
   - YouTube integration
   - Playlist creation

3. **Interactive Playground**
   - Try analysis in real-time
   - Sandbox environment
   - Instant feedback

4. **Gamification**
   - Badges for milestones
   - Progress levels
   - Leaderboards

5. **AI-Powered Hints**
   - Context-aware suggestions
   - Detect user struggles
   - Proactive help

---

## Resources

- [User Guide](./user-guide.md) - Complete usage documentation
- [Features](./features.md) - All feature descriptions
- [FAQ](./faq.md) - Common questions
- [API Reference](./api-reference.md) - API documentation

---

**Version:** 1.0.0
**Last Updated:** December 2024
**Maintainer:** PromptForge Team
