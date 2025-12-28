import React, { useState } from 'react';
import './DemoPrompts.css';

interface DemoPrompt {
  id: string;
  title: string;
  category: string;
  content: string;
  qualityScore: number;
  targetLLM: string;
  icon: string;
  description: string;
}

const demoPrompts: DemoPrompt[] = [
  {
    id: 'blog-post',
    title: 'Blog Post Generator',
    category: 'Content Creation',
    icon: '✍️',
    description: 'High-quality prompt for creating comprehensive blog posts',
    qualityScore: 92,
    targetLLM: 'ChatGPT',
    content: `Write a comprehensive, well-researched blog post about {topic}.

Target Audience: {audience}
Tone: Professional yet conversational, backed by research
Word Count: 1500-2000 words

Structure:
1. Introduction
   - Hook: Start with a relatable scenario
   - Statistics and current relevance
   - Preview of key benefits

2. Main Content
   - 4-5 main sections with H2 subheadings
   - Each section: 300-400 words
   - Include data, research, and expert quotes
   - Practical examples and case studies

3. Actionable Takeaways
   - Numbered list of key points
   - Concrete steps readers can implement
   - Resources and tools

4. Conclusion
   - Summarize key benefits
   - Strong call-to-action
   - Further reading suggestions

SEO Requirements:
- Primary Keyword: {keyword}
- Include keyword naturally 3-5 times
- Use related keywords and semantic variations
- Meta description ready summary in conclusion

Format:
- Clear headings (H1, H2, H3)
- Short paragraphs (3-4 sentences)
- Bullet points for lists
- Callout boxes for important tips`
  },
  {
    id: 'code-review',
    title: 'Code Review Assistant',
    category: 'Development',
    icon: '💻',
    description: 'Thorough code review with best practices',
    qualityScore: 89,
    targetLLM: 'Claude',
    content: `Review the following {language} code and provide comprehensive feedback.

Code Context:
- Purpose: {purpose}
- Framework/Libraries: {frameworks}
- Target Environment: {environment}

Review Criteria:

1. **Code Quality**
   - Clean code principles
   - SOLID principles adherence
   - DRY (Don't Repeat Yourself)
   - Code readability and maintainability

2. **Performance**
   - Time complexity analysis
   - Space complexity analysis
   - Potential bottlenecks
   - Optimization opportunities

3. **Security**
   - Input validation
   - SQL injection prevention
   - XSS vulnerabilities
   - Authentication/authorization checks
   - Sensitive data handling

4. **Best Practices**
   - Language-specific idioms
   - Error handling
   - Logging and monitoring
   - Testing coverage needs

5. **Documentation**
   - Code comments quality
   - Function/method documentation
   - Type hints/annotations
   - README completeness

Output Format:
For each issue found, provide:
- Severity: Critical/High/Medium/Low
- Category: Performance/Security/Quality/Style
- Line numbers
- Current code (problematic)
- Suggested fix with explanation
- Why this matters

End with:
- Overall code quality score (1-10)
- Summary of critical issues
- Priority recommendations (top 3)
- Positive aspects worth keeping`
  },
  {
    id: 'marketing-copy',
    title: 'Marketing Copy Generator',
    category: 'Marketing',
    icon: '📣',
    description: 'Persuasive marketing copy that converts',
    qualityScore: 87,
    targetLLM: 'ChatGPT',
    content: `Create compelling marketing copy for {product_type}.

Product Details:
- Name: {product_name}
- Target Customer: {target_customer}
- Key Benefits: {benefits}
- Price Point: {price}
- Competitive Advantage: {advantage}

Copy Requirements:

1. **Headline** (60 characters max)
   - Benefit-driven, not feature-driven
   - Create emotional connection
   - Include power words
   - Promise transformation

2. **Subheadline** (120 characters)
   - Expand on headline
   - Address pain point
   - Build credibility

3. **Opening Hook** (100 words)
   - Start with relatable problem
   - Agitate the pain point
   - Promise solution

4. **Features as Benefits** (200 words)
   - Transform each technical feature into customer benefit
   - Use "you" language
   - Focus on outcomes, not specifications
   - Include specific numbers and results

5. **Social Proof** (100 words)
   - Customer testimonials
   - Usage statistics
   - Industry recognition
   - Trust badges

6. **Objection Handling** (150 words)
   - Address top 3 concerns
   - Provide reassurance
   - Money-back guarantee
   - Risk reversal

7. **Call-to-Action** (50 words)
   - Clear next step
   - Urgency element
   - Friction reduction
   - Strong action verb

Tone: {tone}
Style: Conversational, benefit-focused, customer-centric
Avoid: Jargon, hype, vague claims`
  },
  {
    id: 'data-analyst',
    title: 'Data Analysis Request',
    category: 'Analytics',
    icon: '📊',
    description: 'Comprehensive data analysis with insights',
    qualityScore: 91,
    targetLLM: 'ChatGPT',
    content: `Analyze the following dataset and provide actionable insights.

Dataset Information:
- Name: {dataset_name}
- Format: {format}
- Size: {size}
- Time Period: {time_period}
- Key Variables: {variables}

Analysis Objectives:
{objectives}

Required Analysis:

1. **Data Quality Assessment**
   - Missing values analysis
   - Outlier detection
   - Data type validation
   - Consistency checks

2. **Descriptive Statistics**
   - Central tendency (mean, median, mode)
   - Dispersion (std dev, variance, range)
   - Distribution shape
   - Key percentiles

3. **Exploratory Data Analysis**
   - Correlation matrix
   - Feature relationships
   - Pattern identification
   - Clustering analysis

4. **Trend Analysis**
   - Time series patterns
   - Seasonality detection
   - Growth/decline rates
   - Forecasting (next 3-6 months)

5. **Segment Analysis**
   - Customer/user segmentation
   - Cohort analysis
   - RFM analysis (if applicable)
   - Behavioral patterns

6. **Statistical Tests**
   - Hypothesis testing
   - Significance levels
   - Confidence intervals
   - A/B test results (if applicable)

7. **Visualization Recommendations**
   - Chart types for each insight
   - Dashboard layout suggestions
   - KPI metrics to track

8. **Business Insights**
   - Key findings (top 5)
   - Surprising patterns
   - Actionable recommendations
   - Risk areas to monitor

Output Format:
- Executive summary (200 words)
- Detailed findings by section
- Visualizations (describe what to create)
- Recommendations with priority
- Next steps for deeper analysis

Technical Level: {technical_level}
Focus: Actionable insights over statistical details`
  },
  {
    id: 'email-sequence',
    title: 'Email Sequence Builder',
    category: 'Communication',
    icon: '📧',
    description: 'Multi-email drip campaign sequence',
    qualityScore: 85,
    targetLLM: 'ChatGPT',
    content: `Create a {num_emails}-email sequence for {campaign_goal}.

Campaign Details:
- Target Audience: {audience}
- Product/Service: {offering}
- Campaign Duration: {duration}
- Desired Action: {action}

Email Sequence Structure:

Email 1: Introduction (Day 1)
- Subject line (A/B test versions)
- Preview text
- Opening: Personal introduction
- Value proposition
- Soft CTA (educational content)
- P.S. teaser for next email

Email 2: Value Delivery (Day {day2})
- Subject: Reference to Email 1
- Main content: Educational value
- Case study or success story
- CTA: Free resource download
- Social proof

Email 3: Problem Agitation (Day {day3})
- Subject: Address pain point
- Content: Deep dive into problem
- Consequences of inaction
- Your solution introduction
- CTA: Learn more

Email 4: Solution Presentation (Day {day4})
- Subject: Benefit-focused
- Content: Detailed solution overview
- Features as benefits
- Pricing/options introduction
- CTA: Book demo/consultation

Email 5: Objection Handling (Day {day5})
- Subject: FAQ or concern-based
- Content: Address top objections
- Testimonials and reviews
- Money-back guarantee
- CTA: Last chance offer

Email 6: Urgency & Closing (Day {day6})
- Subject: Time-sensitive
- Content: Scarcity/urgency
- Recap of benefits
- Final offer
- Strong CTA: Buy now/sign up

For Each Email Provide:
- Subject line (2-3 variations)
- Preview text
- Body copy (250-400 words)
- CTA button text
- P.S. message
- Optimal send time
- Expected open/click rates

Tone: {tone}
Brand Voice: {brand_voice}
Personalization: Include {personalization_fields}`
  },
  {
    id: 'social-media',
    title: 'Social Media Content Calendar',
    category: 'Social Media',
    icon: '📱',
    description: 'Complete social media content strategy',
    qualityScore: 88,
    targetLLM: 'Claude',
    content: `Create a {duration} social media content calendar for {platform}.

Brand Details:
- Industry: {industry}
- Target Audience: {audience}
- Brand Voice: {brand_voice}
- Goals: {goals}
- Posting Frequency: {frequency}

Content Pillars (distribute evenly):
1. Educational (40%)
2. Entertaining (30%)
3. Promotional (20%)
4. User-generated content (10%)

For Each Post Include:

**Post Details:**
- Date and optimal time
- Content pillar
- Post type (image/video/carousel/reel)
- Caption (platform-specific length)
- First comment idea
- Hashtags ({num_hashtags})
- Tagged accounts (if any)

**Caption Structure:**
- Hook (first line - emoji + question/statement)
- Value/story (2-4 sentences)
- Engagement prompt
- Call-to-action
- Hashtags

**Content Ideas by Pillar:**

Educational:
- How-to guides
- Industry tips
- Myth-busting
- Behind-the-scenes
- Expert insights

Entertaining:
- Memes (brand-appropriate)
- Trending audio usage
- Polls and quizzes
- Relatable scenarios
- Fun facts

Promotional:
- Product features
- Customer testimonials
- Limited offers
- New launches
- Case studies

Engagement Tactics:
- Questions for comments
- Fill-in-the-blank
- Tag-a-friend mechanics
- Share-to-story prompts
- Polls and surveys

Analytics to Track:
- Reach and impressions
- Engagement rate
- Click-through rate
- Follower growth
- Best-performing content types

Platform-Specific Optimization:
- Image dimensions: {image_size}
- Video length: {video_length}
- Best posting times: {posting_times}
- Trending hashtags: {trending_tags}

Output Format:
Create a {duration} calendar with:
- Specific post dates
- Complete caption copy
- Visual descriptions
- Hashtag sets
- Engagement strategy for each post`
  }
];

interface DemoPromptsProps {
  onUsePrompt?: (prompt: DemoPrompt) => void;
  onClose?: () => void;
}

const DemoPrompts: React.FC<DemoPromptsProps> = ({ onUsePrompt, onClose }) => {
  const [selectedPrompt, setSelectedPrompt] = useState<DemoPrompt | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>('All');

  const categories = ['All', ...Array.from(new Set(demoPrompts.map(p => p.category)))];

  const filteredPrompts = selectedCategory === 'All'
    ? demoPrompts
    : demoPrompts.filter(p => p.category === selectedCategory);

  const handleViewPrompt = (prompt: DemoPrompt) => {
    setSelectedPrompt(prompt);
  };

  const handleUsePrompt = (prompt: DemoPrompt) => {
    if (onUsePrompt) {
      onUsePrompt(prompt);
    }
  };

  const handleClose = () => {
    if (selectedPrompt) {
      setSelectedPrompt(null);
    } else if (onClose) {
      onClose();
    }
  };

  const getScoreColor = (score: number) => {
    if (score >= 90) return '#10b981';
    if (score >= 75) return '#3b82f6';
    if (score >= 60) return '#f59e0b';
    return '#ef4444';
  };

  return (
    <div className="demo-prompts-overlay">
      <div className="demo-prompts-container">
        {/* Header */}
        <div className="demo-prompts-header">
          <div>
            <h2 className="demo-prompts-title">
              {selectedPrompt ? '📝 Prompt Preview' : '💡 Sample Prompts to Try'}
            </h2>
            <p className="demo-prompts-subtitle">
              {selectedPrompt
                ? 'High-quality prompt examples to learn from'
                : 'Get started with these professional prompt templates'}
            </p>
          </div>
          <button className="demo-prompts-close-btn" onClick={handleClose}>
            {selectedPrompt ? '← Back' : '✕'}
          </button>
        </div>

        {/* Category filters */}
        {!selectedPrompt && (
          <div className="demo-prompts-filters">
            {categories.map(category => (
              <button
                key={category}
                className={`demo-filter-btn ${selectedCategory === category ? 'active' : ''}`}
                onClick={() => setSelectedCategory(category)}
              >
                {category}
              </button>
            ))}
          </div>
        )}

        {/* Content */}
        <div className="demo-prompts-content">
          {!selectedPrompt ? (
            /* Prompts grid */
            <div className="demo-prompts-grid">
              {filteredPrompts.map(prompt => (
                <div key={prompt.id} className="demo-prompt-card">
                  <div className="demo-prompt-card-header">
                    <span className="demo-prompt-icon">{prompt.icon}</span>
                    <div className="demo-prompt-score" style={{ color: getScoreColor(prompt.qualityScore) }}>
                      {prompt.qualityScore}
                      <span className="demo-score-label">/100</span>
                    </div>
                  </div>

                  <h3 className="demo-prompt-card-title">{prompt.title}</h3>
                  <p className="demo-prompt-description">{prompt.description}</p>

                  <div className="demo-prompt-meta">
                    <span className="demo-prompt-badge">{prompt.category}</span>
                    <span className="demo-prompt-badge">{prompt.targetLLM}</span>
                  </div>

                  <div className="demo-prompt-actions">
                    <button
                      className="demo-btn demo-btn-secondary"
                      onClick={() => handleViewPrompt(prompt)}
                    >
                      View Details
                    </button>
                    <button
                      className="demo-btn demo-btn-primary"
                      onClick={() => handleUsePrompt(prompt)}
                    >
                      Use This Prompt
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            /* Prompt detail view */
            <div className="demo-prompt-detail">
              <div className="demo-detail-header">
                <div className="demo-detail-icon-wrapper">
                  <span className="demo-detail-icon">{selectedPrompt.icon}</span>
                </div>
                <div className="demo-detail-info">
                  <h3 className="demo-detail-title">{selectedPrompt.title}</h3>
                  <p className="demo-detail-description">{selectedPrompt.description}</p>
                  <div className="demo-detail-meta">
                    <span className="demo-prompt-badge">{selectedPrompt.category}</span>
                    <span className="demo-prompt-badge">{selectedPrompt.targetLLM}</span>
                    <span
                      className="demo-prompt-badge"
                      style={{
                        background: getScoreColor(selectedPrompt.qualityScore),
                        color: 'white'
                      }}
                    >
                      Quality: {selectedPrompt.qualityScore}/100
                    </span>
                  </div>
                </div>
              </div>

              <div className="demo-detail-content">
                <h4 className="demo-detail-section-title">Prompt Content:</h4>
                <pre className="demo-prompt-content-box">{selectedPrompt.content}</pre>
              </div>

              <div className="demo-detail-actions">
                <button
                  className="demo-btn demo-btn-large demo-btn-primary"
                  onClick={() => handleUsePrompt(selectedPrompt)}
                >
                  Use This Prompt →
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default DemoPrompts;
