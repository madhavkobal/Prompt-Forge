#!/usr/bin/env python3
"""
Seed database with demo data for PromptForge

This script creates:
- Demo user account
- Sample templates for different use cases
- Example prompts with analysis results
- Prompt version history

Usage:
    python scripts/seed_data.py
    python scripts/seed_data.py --reset  # Drop and recreate data
"""
import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import argparse
from sqlalchemy.orm import Session
from app.core.database import SessionLocal, engine, Base
from app.models.user import User
from app.models.prompt import Prompt, Template, PromptVersion
from app.core.security import get_password_hash
from datetime import datetime, timedelta


def get_db():
    """Get database session"""
    db = SessionLocal()
    try:
        return db
    finally:
        pass


def clear_demo_data(db: Session):
    """Clear existing demo data"""
    print("🗑️  Clearing existing demo data...")

    # Delete demo user and all related data (cascades)
    demo_user = db.query(User).filter(User.username == "demo").first()
    if demo_user:
        db.delete(demo_user)
        db.commit()
        print("   ✓ Removed demo user and related data")
    else:
        print("   ℹ No existing demo data found")


def create_demo_user(db: Session) -> User:
    """Create demo user account"""
    print("\n👤 Creating demo user...")

    # Check if user exists
    existing_user = db.query(User).filter(User.username == "demo").first()
    if existing_user:
        print("   ℹ Demo user already exists")
        return existing_user

    demo_user = User(
        email="demo@promptforge.io",
        username="demo",
        full_name="Demo User",
        hashed_password=get_password_hash("DemoPassword123!"),
        is_active=True
    )

    db.add(demo_user)
    db.commit()
    db.refresh(demo_user)

    print(f"   ✓ Created demo user: {demo_user.username}")
    print(f"   📧 Email: {demo_user.email}")
    print(f"   🔑 Password: DemoPassword123!")

    return demo_user


def create_sample_templates(db: Session, user: User):
    """Create sample templates for different use cases"""
    print("\n📋 Creating sample templates...")

    templates_data = [
        {
            "name": "Blog Post Generator",
            "description": "Template for creating comprehensive blog posts on any topic",
            "content": """Write a comprehensive, SEO-optimized blog post about {topic}.

Target Audience: {audience}
Tone: {tone}
Word Count: {word_count} words

Structure:
1. Engaging introduction with a hook
2. {num_sections} main sections with H2 subheadings
3. Practical examples and actionable tips
4. Conclusion with call-to-action

SEO Requirements:
- Primary Keyword: {keyword}
- Include keyword naturally 3-5 times
- Use related keywords and semantic variations
- Meta description ready summary in conclusion

Additional Requirements:
- Include statistics and data where relevant
- Add 2-3 expert quotes or insights
- Provide actionable takeaways
- Use bullet points for readability""",
            "category": "content",
            "tags": ["blog", "writing", "SEO", "content-marketing"],
            "is_public": True
        },
        {
            "name": "Code Documentation",
            "description": "Generate comprehensive technical documentation for code",
            "content": """Create detailed technical documentation for the following {language} code.

Code Context:
- Function/Class Name: {code_name}
- Purpose: {purpose}
- File: {file_path}

Documentation Format: {format}

Required Sections:
1. **Overview**
   - Brief description of functionality
   - Use cases and when to use this code

2. **Parameters**
   - Name, type, and description for each parameter
   - Optional vs required parameters
   - Default values if applicable

3. **Return Value**
   - Return type
   - Description of what's returned
   - Possible return values

4. **Examples**
   - Basic usage example
   - Advanced usage example
   - Edge cases if relevant

5. **Error Handling**
   - Possible exceptions/errors
   - How to handle errors
   - Common pitfalls

6. **Performance**
   - Time complexity
   - Space complexity
   - Performance considerations

7. **Dependencies**
   - Required imports/libraries
   - Version requirements

8. **Testing**
   - How to test this code
   - Example test cases""",
            "category": "code",
            "tags": ["documentation", "code", "technical-writing"],
            "is_public": True
        },
        {
            "name": "Product Description",
            "description": "Create compelling e-commerce product descriptions",
            "content": """Write a compelling product description for {product_name}.

Product Details:
- Category: {category}
- Price Range: {price_range}
- Target Customer: {target_customer}
- Key Features: {features}
- Unique Selling Points: {usp}

Description Requirements:
1. **Headline** (60 characters max)
   - Attention-grabbing and benefit-focused
   - Include primary keyword

2. **Opening Paragraph** (2-3 sentences)
   - Hook the reader emotionally
   - State the main benefit
   - Create desire

3. **Features & Benefits** (bullet points)
   - List 5-7 key features
   - Transform each feature into a customer benefit
   - Use sensory language and specifics

4. **Social Proof** (if available)
   - Customer ratings
   - Testimonial snippets
   - Awards or certifications

5. **Call-to-Action**
   - Urgency or scarcity element
   - Clear next step
   - Risk reversal (guarantee, return policy)

Tone: {tone}
Length: {word_count} words
Keywords: {keywords}""",
            "category": "marketing",
            "tags": ["ecommerce", "copywriting", "product", "marketing"],
            "is_public": True
        },
        {
            "name": "Email Response",
            "description": "Professional email response template for customer service",
            "content": """Compose a professional email response for the following scenario:

Customer Issue: {issue_description}
Customer Sentiment: {sentiment}
Priority Level: {priority}
Response Type: {response_type}

Email Structure:
1. **Subject Line**
   - Clear and specific
   - Include ticket/reference number if applicable

2. **Greeting**
   - Personalized with customer name
   - Appropriate formality level

3. **Acknowledgment**
   - Show understanding of the issue
   - Empathize with customer frustration if applicable
   - Thank them for bringing it to attention

4. **Explanation**
   - Clear explanation of what happened
   - Avoid technical jargon unless necessary
   - Take responsibility if appropriate

5. **Solution**
   - Specific steps being taken
   - Timeline for resolution
   - What customer can expect next

6. **Compensation** (if applicable)
   - Offer compensation/goodwill gesture
   - Explain the value and how to redeem

7. **Prevention**
   - Steps to prevent recurrence
   - Build confidence in the solution

8. **Closing**
   - Offer additional support
   - Provide contact information
   - Professional sign-off

Tone: {tone}
Brand Voice: {brand_voice}
Urgency: {urgency_level}""",
            "category": "communication",
            "tags": ["email", "customer-service", "support", "communication"],
            "is_public": True
        },
        {
            "name": "Data Analysis Request",
            "description": "Prompt template for requesting data analysis and insights",
            "content": """Analyze the following dataset and provide comprehensive insights:

Dataset: {dataset_description}
Data Format: {format}
Size: {size}
Time Period: {time_period}

Analysis Objectives:
{objectives}

Required Analysis:
1. **Descriptive Statistics**
   - Summary statistics (mean, median, mode, std dev)
   - Distribution analysis
   - Missing data assessment

2. **Trend Analysis**
   - Identify patterns over time
   - Seasonal variations
   - Growth rates

3. **Correlation Analysis**
   - Relationships between variables
   - Strength and direction of correlations
   - Causation vs correlation insights

4. **Segmentation**
   - Group similar data points
   - Identify distinct segments
   - Characteristics of each segment

5. **Anomaly Detection**
   - Identify outliers
   - Unusual patterns
   - Potential data quality issues

6. **Predictive Insights**
   - Future trends based on historical data
   - Confidence intervals
   - Key drivers and factors

7. **Actionable Recommendations**
   - Business implications
   - Strategic recommendations
   - Priority actions

Output Format: {output_format}
Visualization Requirements: {viz_requirements}
Technical Level: {technical_level}""",
            "category": "analysis",
            "tags": ["data", "analysis", "insights", "business-intelligence"],
            "is_public": True
        },
        {
            "name": "Social Media Post",
            "description": "Engaging social media content template",
            "content": """Create an engaging social media post for {platform}.

Content Topic: {topic}
Campaign Goal: {goal}
Target Audience: {audience}
Brand Voice: {brand_voice}

Post Requirements:
1. **Hook** (First line/sentence)
   - Grab attention immediately
   - Ask question or make bold statement
   - Use emojis strategically for {platform}

2. **Value Proposition**
   - Clear benefit or insight
   - Solve a problem or answer a question
   - Provide value upfront

3. **Story/Content**
   - {content_length} approach
   - Relatable scenario or example
   - Conversational tone

4. **Call-to-Action**
   - Clear next step
   - Link to {cta_destination}
   - Urgency or incentive

5. **Hashtags**
   - {num_hashtags} relevant hashtags
   - Mix of popular and niche tags
   - Branded hashtag if applicable

Platform-Specific Optimization:
- Character count: {char_limit}
- Best posting time: {posting_time}
- Visual suggestion: {visual_type}

Engagement Triggers:
- Question for comments
- Tag a friend mechanic
- Share if you agree
- Story/poll opportunity""",
            "category": "social-media",
            "tags": ["social-media", "content", "engagement", "marketing"],
            "is_public": True
        },
        {
            "name": "Meeting Agenda",
            "description": "Structured meeting agenda template for productive meetings",
            "content": """Create a comprehensive meeting agenda for:

Meeting Type: {meeting_type}
Duration: {duration}
Attendees: {attendees}
Meeting Goal: {goal}

Agenda Structure:

**Pre-Meeting**
- Date & Time: {date_time}
- Location/Link: {location}
- Required Prep: {prep_work}

**1. Opening (5 minutes)**
- Welcome and introductions
- Agenda review
- Ground rules reminder

**2. Context Setting ({context_time} minutes)**
- Background information
- Problem statement
- Success criteria for this meeting

**3. Main Discussion Topics**

Topic 1: {topic_1}
- Time Allocated: {time_1}
- Discussion Points:
  * {discussion_points_1}
- Decision Needed: {decision_1}
- Owner: {owner_1}

Topic 2: {topic_2}
- Time Allocated: {time_2}
- Discussion Points:
  * {discussion_points_2}
- Decision Needed: {decision_2}
- Owner: {owner_2}

[Add more topics as needed]

**4. Action Items Review ({review_time} minutes)**
- Capture all action items
- Assign owners
- Set deadlines
- Identify dependencies

**5. Next Steps ({next_steps_time} minutes)**
- Summarize decisions
- Confirm action items
- Schedule follow-up if needed
- Parking lot items

**6. Closing (5 minutes)**
- Key takeaways
- Feedback on meeting effectiveness
- Thank participants

**Meeting Artifacts:**
- Notes Template: {notes_template}
- Recording: {recording_option}
- Follow-up: {followup_plan}""",
            "category": "business",
            "tags": ["meeting", "agenda", "productivity", "business"],
            "is_public": True
        }
    ]

    created_count = 0
    for template_data in templates_data:
        # Check if template already exists
        existing = db.query(Template).filter(
            Template.name == template_data["name"],
            Template.owner_id == user.id
        ).first()

        if not existing:
            template = Template(
                **template_data,
                owner_id=user.id
            )
            db.add(template)
            created_count += 1

    db.commit()
    print(f"   ✓ Created {created_count} sample templates")
    if created_count < len(templates_data):
        print(f"   ℹ Skipped {len(templates_data) - created_count} existing templates")


def create_sample_prompts(db: Session, user: User):
    """Create example prompts with realistic analysis results"""
    print("\n📝 Creating sample prompts...")

    prompts_data = [
        {
            "title": "High-Quality Blog Post Prompt",
            "content": """Write a comprehensive, well-researched blog post about the benefits of meditation for software developers.

Target Audience: Software developers and tech professionals aged 25-40
Tone: Professional yet conversational, backed by research
Word Count: 1500-2000 words

Structure:
1. Introduction
   - Hook: Start with a relatable scenario of developer burnout
   - Statistics on stress in tech industry
   - Preview of meditation benefits

2. The Science Behind Meditation
   - Neuroplasticity and meditation
   - Research from neuroscience studies
   - How it affects the developer brain

3. Specific Benefits for Developers
   - Improved focus and concentration (crucial for coding)
   - Enhanced problem-solving abilities
   - Better debugging mindset
   - Reduced stress and burnout prevention
   - Improved work-life balance

4. Getting Started with Meditation
   - Simple 5-minute daily practice
   - Apps and tools for developers
   - Integration into daily routine
   - Common obstacles and solutions

5. Real Stories
   - Include 2-3 testimonials from developers
   - Before/after experiences
   - Productivity metrics if available

6. Conclusion
   - Summarize key benefits
   - Call-to-action: 7-day meditation challenge
   - Resources and further reading

SEO Keywords: meditation for developers, programmer wellness, tech stress management
Include relevant statistics and cite 3-5 research studies
Add practical code-break meditation exercises
Format with clear headings, bullet points, and callout boxes""",
            "target_llm": "ChatGPT",
            "category": "content",
            "tags": ["blog", "wellness", "tech"],
            "quality_score": 92.5,
            "clarity_score": 95.0,
            "specificity_score": 90.0,
            "structure_score": 93.0,
            "suggestions": [
                "Consider adding a sidebar with quick meditation tips",
                "Include a downloadable meditation schedule template",
                "Add links to meditation apps with developer discounts"
            ],
            "best_practices": {
                "has_clear_instruction": "excellent",
                "has_context": "excellent",
                "has_constraints": "excellent",
                "has_examples": "good",
                "has_output_format": "excellent"
            },
            "enhanced_content": None
        },
        {
            "title": "Medium-Quality Product Description",
            "content": """Write a product description for our new wireless earbuds. They have good sound quality, long battery life, and are comfortable. Price is $79.99. Make it sound professional and highlight the features.""",
            "target_llm": "ChatGPT",
            "category": "marketing",
            "tags": ["product", "ecommerce"],
            "quality_score": 65.0,
            "clarity_score": 70.0,
            "specificity_score": 55.0,
            "structure_score": 70.0,
            "suggestions": [
                "Add specific details: exactly how long is the battery life?",
                "Define target customer (athletes, commuters, audiophiles?)",
                "Specify desired tone (luxury, budget-friendly, technical?)",
                "Include word count requirement",
                "Mention key differentiators from competitors",
                "Specify output format (bullet points, paragraphs, both?)",
                "Add SEO keyword requirements",
                "Include call-to-action guidance"
            ],
            "best_practices": {
                "has_clear_instruction": "good",
                "has_context": "fair",
                "has_constraints": "poor",
                "has_examples": "poor",
                "has_output_format": "poor"
            },
            "enhanced_content": """Write a compelling e-commerce product description for our new AirFlow Pro wireless earbuds.

Product Details:
- Model: AirFlow Pro Wireless Earbuds
- Price: $79.99
- Category: Audio/Electronics
- Target Customer: Active professionals and fitness enthusiasts aged 25-45

Key Features:
- Premium sound quality with active noise cancellation
- Extended battery life: 8 hours per charge, 32 hours with charging case
- Ergonomic design with multiple ear tip sizes for all-day comfort
- IPX5 water resistance (sweat and splash proof)
- Quick charge: 15 minutes = 2 hours playback
- Bluetooth 5.2 for stable connection
- Touch controls for music and calls

Unique Selling Points:
- Better sound quality than competitors at this price point
- Longest battery life in the sub-$100 category
- Designed by audiophiles, tested by athletes
- Premium feel without premium price

Description Requirements:

1. **Headline** (50-60 characters)
   - Benefit-focused and attention-grabbing
   - Include "wireless earbuds" for SEO

2. **Opening Hook** (2-3 sentences)
   - Address pain point: tangled wires, poor battery, uncomfortable fit
   - Promise transformation: freedom, all-day listening, comfort
   - Create emotional connection

3. **Features & Benefits** (5-7 bullet points)
   - Transform each technical feature into a customer benefit
   - Use sensory language ("crystal-clear sound", "feather-light comfort")
   - Focus on use cases (commute, workout, work calls)

4. **Social Proof**
   - Mention 4.8/5 star rating
   - "Rated #1 in comfort by AudioTech Review"
   - "Over 10,000 happy customers"

5. **Call-to-Action**
   - 30-day money-back guarantee
   - Free shipping on orders over $50
   - Limited stock alert

Tone: Enthusiastic but authentic, premium but accessible
Length: 300-400 words
SEO Keywords: wireless earbuds, noise cancelling earbuds, workout headphones
Format: Mix of paragraphs and bullet points for scannability"""
        },
        {
            "title": "Poor-Quality Email Request",
            "content": "Write an email to customers about the new product launch next week.",
            "target_llm": "Claude",
            "category": "communication",
            "tags": ["email"],
            "quality_score": 35.0,
            "clarity_score": 45.0,
            "specificity_score": 25.0,
            "structure_score": 35.0,
            "suggestions": [
                "Specify what product is being launched",
                "Define target customer segment",
                "Clarify email goal (awareness, pre-order, exclusive access?)",
                "Add details about the product and its benefits",
                "Specify tone and brand voice",
                "Include subject line requirements",
                "Add word count or length guidance",
                "Mention any special offers or incentives",
                "Define call-to-action",
                "Specify email structure (sections, formatting)"
            ],
            "best_practices": {
                "has_clear_instruction": "fair",
                "has_context": "very poor",
                "has_constraints": "very poor",
                "has_examples": "none",
                "has_output_format": "very poor"
            },
            "enhanced_content": None
        },
        {
            "title": "Code Documentation Example",
            "content": """Generate comprehensive API documentation for our user authentication endpoint.

Endpoint: POST /api/v1/auth/login
Purpose: Authenticate users and issue JWT tokens

Technical Details:
- Framework: FastAPI (Python 3.11)
- Authentication Method: JWT with bcrypt password hashing
- Database: PostgreSQL
- Rate Limiting: 5 attempts per minute per IP

Documentation Format: OpenAPI 3.0 compatible

Required Sections:

1. **Endpoint Overview**
   - HTTP method and path
   - Brief description (1-2 sentences)
   - Authentication requirements (none for this endpoint)

2. **Request Specification**
   Request Body (application/x-www-form-urlencoded):
   - username (string, required): User's username
   - password (string, required): User's password

   Include JSON schema for validation

3. **Response Specification**
   Success Response (200 OK):
   {
     "access_token": "eyJhbG...",
     "token_type": "bearer"
   }

   Error Responses:
   - 401: Invalid credentials
   - 429: Rate limit exceeded
   - 422: Validation error

   Include example responses for each status code

4. **Security Considerations**
   - Password requirements
   - Token expiration (30 minutes)
   - Rate limiting details
   - HTTPS requirement

5. **Code Examples**
   - Python (requests library)
   - JavaScript (fetch API)
   - cURL command

6. **Common Errors and Solutions**
   - Invalid credentials
   - Account locked
   - Rate limit exceeded

7. **Testing**
   - How to test in development
   - Test account credentials
   - Expected response times (<200ms)

Style: Technical but clear, suitable for both beginners and experienced developers
Include interactive "Try it out" notice for Swagger UI
Add related endpoints (register, logout, refresh token)""",
            "target_llm": "ChatGPT",
            "category": "code",
            "tags": ["documentation", "API", "technical"],
            "quality_score": 88.0,
            "clarity_score": 90.0,
            "specificity_score": 92.0,
            "structure_score": 82.0,
            "suggestions": [
                "Add versioning information for the API",
                "Include deprecation timeline if applicable",
                "Mention backward compatibility considerations"
            ],
            "best_practices": {
                "has_clear_instruction": "excellent",
                "has_context": "excellent",
                "has_constraints": "good",
                "has_examples": "excellent",
                "has_output_format": "excellent"
            },
            "enhanced_content": None
        },
        {
            "title": "Social Media Content",
            "content": """Create an Instagram post announcing our new eco-friendly product line.

Product Line: Sustainable Home Goods Collection
Launch Date: Next Monday
Target Audience: Environmentally conscious millennials and Gen Z (ages 24-40)
Brand Voice: Authentic, optimistic, action-oriented

Post Requirements:

1. **Hook** (First line)
   - Start with "🌍 Big news for our planet-loving community!"
   - Create curiosity and excitement
   - Use emojis strategically (2-3 relevant ones)

2. **Product Introduction**
   - Introduce the Sustainable Home Goods Collection
   - Highlight 3 key categories: kitchenware, storage, cleaning supplies
   - Emphasize 100% plastic-free, biodegradable materials

3. **Impact Statement**
   - Share the environmental impact
   - "Every purchase removes X plastic items from production"
   - Connect to bigger mission

4. **Social Proof**
   - Mention: "9 months of R&D with sustainability experts"
   - Partner organizations (if any)

5. **Exclusive Preview**
   - Early access for followers who comment with 🌱
   - Link in bio for full collection
   - Limited launch quantities

6. **Call-to-Action**
   - "Set your reminder for Monday 9 AM EST"
   - "Tag a friend who'd love this"
   - "What sustainable swap are you most excited about?"

7. **Hashtags**
   - Use 20-25 hashtags
   - Mix: #SustainableLiving #EcoFriendly #PlasticFree
   - Brand hashtag: #[YourBrand]GreenLiving
   - Location-based if relevant

Character count: 2,100-2,200 (Instagram limit: 2,200)
Emojis: Use naturally throughout (10-15 total)
Line breaks: Use for readability (double space between sections)

Engagement mechanics:
- Comment with 🌱 for early access
- Tag 2 friends
- Share to story for bonus entry (mention in caption)

Visual suggestion: Carousel post with product photos + impact infographic""",
            "target_llm": "Claude",
            "category": "social-media",
            "tags": ["Instagram", "marketing", "launch"],
            "quality_score": 85.0,
            "clarity_score": 88.0,
            "specificity_score": 90.0,
            "structure_score": 78.0,
            "suggestions": [
                "Add guidelines for tone variations (casual vs professional)",
                "Specify A/B testing strategy for captions",
                "Include best posting time recommendation"
            ],
            "best_practices": {
                "has_clear_instruction": "excellent",
                "has_context": "excellent",
                "has_constraints": "good",
                "has_examples": "good",
                "has_output_format": "excellent"
            },
            "enhanced_content": None
        }
    ]

    created_count = 0
    for i, prompt_data in enumerate(prompts_data, 1):
        # Check if prompt already exists
        existing = db.query(Prompt).filter(
            Prompt.title == prompt_data["title"],
            Prompt.owner_id == user.id
        ).first()

        if not existing:
            # Create prompt with analysis results
            prompt = Prompt(
                **prompt_data,
                owner_id=user.id,
                created_at=datetime.utcnow() - timedelta(days=len(prompts_data) - i)
            )
            db.add(prompt)
            db.flush()  # Get the ID

            # Create initial version
            version = PromptVersion(
                prompt_id=prompt.id,
                version_number=1,
                content=prompt_data["content"],
                created_at=prompt.created_at
            )
            db.add(version)

            # For some prompts, create version history
            if i <= 2:  # First two prompts have version history
                version_2 = PromptVersion(
                    prompt_id=prompt.id,
                    version_number=2,
                    content=prompt_data["enhanced_content"] or prompt_data["content"] + "\n\n[Enhanced version]",
                    created_at=prompt.created_at + timedelta(hours=2)
                )
                db.add(version_2)

            created_count += 1

    db.commit()
    print(f"   ✓ Created {created_count} sample prompts with analysis results")
    if created_count < len(prompts_data):
        print(f"   ℹ Skipped {len(prompts_data) - created_count} existing prompts")


def main():
    """Main function to seed database"""
    parser = argparse.ArgumentParser(description="Seed PromptForge database with demo data")
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Clear existing demo data before seeding"
    )
    args = parser.parse_args()

    print("=" * 60)
    print("🌱 PromptForge Database Seeder")
    print("=" * 60)

    try:
        # Create database session
        db = get_db()

        # Reset if requested
        if args.reset:
            clear_demo_data(db)

        # Create demo user
        demo_user = create_demo_user(db)

        # Create sample data
        create_sample_templates(db, demo_user)
        create_sample_prompts(db, demo_user)

        print("\n" + "=" * 60)
        print("✅ Database seeding completed successfully!")
        print("=" * 60)
        print("\n📝 Demo Account Credentials:")
        print("   Username: demo")
        print("   Password: DemoPassword123!")
        print("   Email: demo@promptforge.io")
        print("\n🚀 You can now log in with these credentials to explore!")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ Error seeding database: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

    finally:
        db.close()


if __name__ == "__main__":
    main()
