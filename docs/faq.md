# Frequently Asked Questions (FAQ)

Common questions about PromptForge and prompt engineering.

## Table of Contents

1. [General Questions](#general-questions)
2. [Account & Authentication](#account--authentication)
3. [Prompt Analysis](#prompt-analysis)
4. [Prompt Enhancement](#prompt-enhancement)
5. [Templates](#templates)
6. [Pricing & Limits](#pricing--limits)
7. [Technical Questions](#technical-questions)
8. [Troubleshooting](#troubleshooting)

---

## General Questions

### What is PromptForge?

PromptForge is an AI-powered platform that helps you create, analyze, and enhance prompts for Large Language Models (LLMs) like ChatGPT, Claude, and Gemini. It provides quality scoring, improvement suggestions, and automated enhancement powered by Google Gemini AI.

### Who should use PromptForge?

- **Content Creators**: Writers, marketers, bloggers creating AI-generated content
- **Developers**: Building AI-powered applications
- **Product Managers**: Designing AI features and interactions
- **Educators**: Teaching prompt engineering and AI literacy
- **Researchers**: Studying LLM behavior and optimization
- **Business Users**: Leveraging AI for productivity

### Is PromptForge free to use?

Yes! The current version is completely free and open-source. You can self-host it or use it online without any cost.

### What LLMs does PromptForge support?

PromptForge can analyze and enhance prompts for:
- ChatGPT (GPT-3.5, GPT-4)
- Google Gemini
- Anthropic Claude
- Generic LLMs
- Any custom LLM (you specify the target)

### How is PromptForge different from just using ChatGPT?

PromptForge provides:
- **Systematic Analysis**: Objective quality scores across multiple dimensions
- **Best Practices**: Automated checks against prompt engineering guidelines
- **Improvement Tracking**: See your progress over time
- **Reusable Templates**: Save and share successful patterns
- **Multi-Model**: Optimize for different LLMs
- **Version Control**: Track changes and iterations

---

## Account & Authentication

### How do I create an account?

1. Visit the PromptForge homepage
2. Click "Sign Up"
3. Enter email, username, and password
4. Password must meet security requirements (8+ chars, uppercase, lowercase, digit, special char)
5. Click "Create Account"

### What are the password requirements?

Passwords must include:
- ✅ Minimum 8 characters
- ✅ At least one uppercase letter (A-Z)
- ✅ At least one lowercase letter (a-z)
- ✅ At least one digit (0-9)
- ✅ At least one special character (!@#$%^&*...)
- ❌ Cannot be a common password (password123, qwerty, etc.)

**Example strong passwords:**
- `MyPrompt2024!`
- `Secure#AI99`
- `PromptMaster$2024`

### I forgot my password. How do I reset it?

Password reset is currently in development. For now, please contact support at support@promptforge.io with your username and email.

### Can I change my email address?

Yes, but this feature is currently in development. For urgent requests, contact support@promptforge.io.

### How long does my session last?

Your login session (JWT token) lasts 30 minutes. After that, you'll need to log in again. This is for security purposes.

### Can I stay logged in permanently?

Not currently. For security reasons, sessions expire after 30 minutes of inactivity. A "Remember Me" feature is planned for future release.

---

## Prompt Analysis

### How does prompt analysis work?

PromptForge uses Google Gemini AI to analyze your prompts. The AI evaluates:
- **Clarity**: How understandable your instructions are
- **Specificity**: Level of detail and precision
- **Structure**: Organization and logical flow
- **Best Practices**: Alignment with prompt engineering guidelines

The system generates a comprehensive report with scores, strengths, weaknesses, and suggestions.

### What do the quality scores mean?

Scores range from 0-100:

| Score | Rating | Meaning |
|-------|--------|---------|
| 90-100 | Excellent | Production-ready, follows best practices |
| 75-89 | Good | Effective prompt, minor improvements possible |
| 60-74 | Fair | Works but needs improvement |
| 40-59 | Poor | Significant issues, needs revision |
| 0-39 | Very Poor | Major problems, complete rewrite recommended |

### How long does analysis take?

Typical analysis time is 3-5 seconds, depending on:
- Prompt length
- Complexity
- AI API response time
- Server load

### Can I analyze multiple prompts at once?

Not currently through the UI, but you can use the API endpoint `/analysis/batch` to analyze multiple prompts in one request. Batch UI is planned for a future release.

### Why did my prompt get a low score?

Common reasons for low scores:
- **Too vague**: Lacks specific details or context
- **No output format**: Doesn't specify desired response format
- **Missing context**: Doesn't provide background information
- **Unclear instructions**: Ambiguous or confusing directions
- **No examples**: Doesn't show what you want
- **Poor structure**: Disorganized or hard to follow

Check the "Weaknesses" and "Suggestions" sections in your analysis report for specific issues.

### Are the scores subjective or objective?

Scores are generated by AI analysis, which provides consistency but isn't perfect. Consider scores as helpful guidance rather than absolute truth. Your real measure of success should be the quality of outputs from your target LLM.

---

## Prompt Enhancement

### How does enhancement work?

PromptForge uses AI to improve your prompt by:
1. Analyzing current weaknesses
2. Adding missing context
3. Clarifying instructions
4. Specifying output format
5. Adding constraints
6. Including examples
7. Improving structure

### Should I always use the enhanced version?

Not necessarily! Enhancement suggestions are recommendations. You should:
- Review the enhanced version carefully
- Understand what changed and why
- Test both versions with your target LLM
- Keep what works for your use case
- Customize as needed

### Can I customize the enhancement?

Yes! After viewing the enhanced version:
1. Click "Edit" to modify it
2. Keep parts you like
3. Remove or change parts that don't fit
4. Save as a new version
5. Continue iterating

### Why does enhancement sometimes make prompts longer?

Enhancement often adds:
- **Context**: Background information for clarity
- **Examples**: To demonstrate desired output
- **Format specifications**: Detailed structure requirements
- **Constraints**: Explicit limitations and requirements

Longer prompts can be more effective because they're more specific and provide better guidance to the AI.

### Can I enhance the same prompt multiple times?

Yes! You can:
- Enhance, review, enhance again
- Generate multiple variant enhancements
- Iterate until you're satisfied
- Each enhancement creates a new version

### Do enhancements always improve quality?

Usually, but not always. Effectiveness depends on:
- Your original prompt quality
- Your specific use case
- Target LLM preferences
- Domain-specific requirements

Always test enhanced prompts with your target LLM and measure real-world results.

---

## Templates

### What are templates?

Templates are reusable prompt patterns with placeholders. For example:

```
Write a {format} about {topic} for {audience}.
The {format} should be {tone} in tone and approximately {length} words.
```

You fill in the placeholders to generate customized prompts quickly.

### Can I create my own templates?

Yes! To create a template:
1. Click "Create Template"
2. Write your template with `{placeholder}` syntax
3. Add description and category
4. Choose public or private
5. Save

### How do I use someone else's template?

1. Browse the template library
2. Click on a template you like
3. Click "Use Template"
4. Fill in the required placeholders
5. Click "Create Prompt"

### Can I edit public templates?

You can't edit other users' templates directly, but you can:
- Clone the template to your account
- Make modifications to your copy
- Save as your own template
- Share your improved version publicly

### How do I share my templates?

When creating or editing a template, toggle "Public" to Yes. Public templates appear in the community library for all users to discover and use.

### Can I delete or unpublish a template?

Yes:
- **Delete**: Permanently removes the template (your copy only)
- **Make Private**: Edit template and set Public to No

Note: If others have already cloned your public template, they keep their copies even if you delete yours.

---

## Pricing & Limits

### Is PromptForge free?

Yes, the current version is completely free to use.

### Are there any usage limits?

Current version has rate limiting for security:
- 60 requests per minute per user/IP
- No hard limits on prompts or analyses

Future paid tiers may introduce:
- Higher rate limits
- Additional features
- Team collaboration
- Priority support

### Will there be a paid version?

Potentially in the future. Planned Pro features might include:
- Unlimited analyses
- Advanced analytics
- Team workspaces
- API access without limits
- Priority support
- Custom branding

The free tier will always remain available.

### Can I use PromptForge commercially?

Yes! The MIT license allows commercial use. You can:
- Use it in your business
- Integrate it into your products
- Self-host for commercial purposes
- Offer it as a service

Please review the LICENSE file for details.

### How much does Gemini API usage cost?

If you're self-hosting, you'll need your own Gemini API key. Costs depend on:
- Gemini API pricing (check Google's current rates)
- Your usage volume
- Prompt lengths

Typical costs are very low (fractions of a cent per analysis).

---

## Technical Questions

### What technology stack does PromptForge use?

**Backend:**
- Python 3.11
- FastAPI framework
- PostgreSQL database
- SQLAlchemy ORM
- Google Gemini AI API

**Frontend:**
- React 18
- TypeScript
- Vite build tool
- TailwindCSS
- React Router

**Infrastructure:**
- Docker containers
- Kubernetes-ready
- Prometheus metrics
- Sentry error tracking

### Can I self-host PromptForge?

Yes! PromptForge is open-source. See [Development Guide](./development.md) and [Deployment Guide](./deployment/) for instructions.

### Does PromptForge store my prompts?

Yes, your prompts are stored in the database so you can:
- Access them later
- Track version history
- Analyze improvement over time
- Use them in templates

Data is stored securely with:
- Encrypted connections (HTTPS)
- Database encryption (optional)
- Access controls
- Regular backups

### Is my data secure?

Yes. PromptForge implements:
- HTTPS encryption in transit
- Password hashing (bcrypt)
- SQL injection prevention
- XSS protection
- CSRF protection
- Rate limiting
- Input sanitization

See [SECURITY.md](../SECURITY.md) for full details.

### Can I export my data?

Yes! You can export:
- Individual prompts (JSON, TXT, Markdown)
- All prompts (bulk export as ZIP)
- Templates (JSON export)

Data portability is important to us.

### What browsers are supported?

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+
- Mobile browsers (iOS Safari, Chrome Mobile)

### Is there a mobile app?

Not yet, but it's planned! Currently, the web interface is mobile-responsive and works on phones and tablets.

### Does PromptForge work offline?

No, PromptForge requires internet connection for:
- AI analysis (Gemini API)
- Data synchronization
- Authentication

Offline mode is being considered for future releases.

---

## Troubleshooting

### I can't log in. What should I do?

1. **Check your credentials**: Username and password are case-sensitive
2. **Verify password**: Make sure Caps Lock is off
3. **Clear browser cache**: Sometimes helps with login issues
4. **Try different browser**: Rule out browser-specific issues
5. **Check rate limits**: Wait a minute if you tried many times
6. **Contact support**: If none of above work

### My analysis is taking too long

If analysis takes more than 15 seconds:
1. **Refresh the page**: The request may have timed out
2. **Try again**: Temporary API issues can occur
3. **Shorten your prompt**: Very long prompts take longer
4. **Check internet connection**: Slow connection affects response time
5. **Try later**: High server load can slow processing

### Why do I get "Rate limit exceeded" error?

You've exceeded 60 requests per minute. This is a security measure. Wait one minute and try again. If you need higher limits for legitimate use, contact support.

### My enhanced prompt doesn't look better

Enhancement quality can vary. Try:
- **Multiple variants**: Generate 3 versions and compare
- **Manual editing**: Combine AI suggestions with your expertise
- **Iterate**: Enhance multiple times with different approaches
- **Provide feedback**: Help us improve (GitHub issues)

### I found a bug. How do I report it?

1. Check [existing issues](https://github.com/madhavkobal/Prompt-Forge/issues)
2. If not reported, create new issue
3. Include:
   - What you were trying to do
   - What happened
   - What you expected
   - Steps to reproduce
   - Screenshots (if applicable)
   - Browser and OS info

### Can I request a feature?

Absolutely! Feature requests are welcome:
1. Search [feature requests](https://github.com/madhavkobal/Prompt-Forge/issues?q=is%3Aissue+label%3Aenhancement)
2. If not exists, create new issue with label `enhancement`
3. Describe the feature and why it's valuable
4. Provide use case examples

---

## Still Have Questions?

**📚 Check the Documentation**
- [User Guide](./user-guide.md)
- [Features](./features.md)
- [API Reference](./api-reference.md)
- [Development Guide](./development.md)

**💬 Community**
- [GitHub Discussions](https://github.com/madhavkobal/Prompt-Forge/discussions)
- Discord Server (coming soon)

**📧 Contact Support**
- Email: support@promptforge.io
- GitHub Issues: [Report a Problem](https://github.com/madhavkobal/Prompt-Forge/issues)

**🐛 Found a Bug?**
- [Report on GitHub](https://github.com/madhavkobal/Prompt-Forge/issues/new)

---

**Last Updated:** December 2024
**Version:** 1.0.0
