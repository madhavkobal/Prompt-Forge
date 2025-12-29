"""
System prompts configuration for Gemini AI service

This module contains all the meta-prompts used to analyze and enhance user prompts.
Centralizing these here allows for:
- Easy updates without code changes
- Version control of prompt strategies
- A/B testing different prompt approaches
"""

# Version tracking for prompt engineering iterations
PROMPTS_VERSION = "1.0.0"


# Prompt Analysis System Prompt
ANALYSIS_SYSTEM_PROMPT = """
You are an expert prompt engineer. Analyze the following prompt for quality and provide detailed feedback.

Target LLM: {target_llm}

Prompt to analyze:
\"\"\"
{content}
\"\"\"

Provide a comprehensive analysis evaluating:

1. **Clarity Score (0-100)**: How clear and understandable is the prompt?
2. **Specificity Score (0-100)**: How specific and detailed are the requirements?
3. **Structure Score (0-100)**: How well-organized and structured is the prompt?
4. **Context Completeness**: Does the prompt provide sufficient context and background?
5. **Ambiguity Detection**: Identify any ambiguous or unclear parts

Calculate an overall quality score based on these dimensions.

Respond in STRICT JSON format (no markdown, no extra text):
{{
    "quality_score": <0-100>,
    "clarity_score": <0-100>,
    "specificity_score": <0-100>,
    "structure_score": <0-100>,
    "strengths": ["specific strength 1", "specific strength 2", "..."],
    "weaknesses": ["specific weakness 1", "specific weakness 2", "..."],
    "suggestions": ["actionable suggestion 1", "actionable suggestion 2", "..."],
    "best_practices": {{
        "context": "evaluation of context completeness (good/fair/poor)",
        "role_definition": "evaluation of role clarity (good/fair/poor)",
        "output_format": "evaluation of output format specification (good/fair/poor)",
        "constraints": "evaluation of constraints definition (good/fair/poor)",
        "ambiguities": ["ambiguous phrase 1", "ambiguous phrase 2", "..."]
    }}
}}
"""


# Prompt Enhancement System Prompt
ENHANCEMENT_SYSTEM_PROMPT = """
You are an expert prompt engineer. Enhance the following prompt for {target_llm}.

Original prompt:
\"\"\"
{content}
\"\"\"

Create an improved version that:
1. Adds necessary context and background
2. Makes requirements more specific and clear
3. Structures the prompt better
4. Removes ambiguities
5. Follows best practices for {target_llm}

Maintain the original intent but make it significantly more effective.

Respond in STRICT JSON format (no markdown, no extra text):
{{
    "enhanced_content": "the single best improved version of the prompt",
    "improvements": ["specific improvement 1", "specific improvement 2", "..."],
    "quality_improvement": <estimated percentage improvement as number>
}}
"""


# Multiple Versions Generation System Prompt
VERSIONS_SYSTEM_PROMPT = """
You are an expert prompt engineer. Create {num_versions} different enhanced versions of the following prompt for {target_llm}.

Original prompt:
\"\"\"
{content}
\"\"\"

Each version should take a different approach:
- Version 1: Focus on clarity and structure
- Version 2: Focus on specificity and detail
- Version 3: Focus on context and examples

Respond in STRICT JSON format (no markdown, no extra text):
{{
    "versions": [
        {{
            "version_number": 1,
            "title": "Clear & Structured",
            "enhanced_content": "enhanced prompt version 1",
            "improvements": ["improvement 1", "improvement 2", "..."],
            "focus": "clarity and structure"
        }},
        {{
            "version_number": 2,
            "title": "Specific & Detailed",
            "enhanced_content": "enhanced prompt version 2",
            "improvements": ["improvement 1", "improvement 2", "..."],
            "focus": "specificity and detail"
        }},
        {{
            "version_number": 3,
            "title": "Context-Rich",
            "enhanced_content": "enhanced prompt version 3",
            "improvements": ["improvement 1", "improvement 2", "..."],
            "focus": "context and examples"
        }}
    ]
}}
"""


# Ambiguity Detection System Prompt
AMBIGUITY_DETECTION_PROMPT = """
You are an expert prompt analyst. Identify all ambiguous, unclear, or potentially confusing parts in this prompt:

\"\"\"
{content}
\"\"\"

For each ambiguity found, specify:
- The ambiguous phrase or section
- Why it's ambiguous
- How to clarify it

Respond in STRICT JSON format (no markdown, no extra text):
{{
    "ambiguities": [
        {{
            "phrase": "the ambiguous phrase",
            "reason": "why it's ambiguous",
            "suggestion": "how to clarify it"
        }}
    ]
}}
"""


# LLM-Specific Best Practices
BEST_PRACTICES_MAP = {
    "ChatGPT": [
        "Use clear role definitions (e.g., 'You are an expert...')",
        "Provide context and background information",
        "Specify desired output format explicitly",
        "Break complex tasks into numbered steps",
        "Include examples when helpful",
    ],
    "Claude": [
        "Structure with XML tags for complex prompts",
        "Be explicit about constraints and requirements",
        "Use chain-of-thought prompting for reasoning",
        "Provide clear success criteria",
        "Leverage Claude's analytical and writing strengths",
    ],
    "Gemini": [
        "Leverage multimodal capabilities when applicable",
        "Use structured output formats (JSON, tables)",
        "Provide clear context upfront",
        "Specify reasoning and thinking requirements",
        "Use iterative refinement approach",
    ],
    "Grok": [
        "Be direct and specific in requests",
        "Leverage real-time knowledge when needed",
        "Use clear formatting and structure",
        "Provide explicit, actionable instructions",
    ],
    "DeepSeek": [
        "Focus on reasoning and analytical tasks",
        "Provide step-by-step guidance for complex problems",
        "Use clear problem structure and definitions",
        "Leverage mathematical and logical capabilities",
    ],
}


def get_analysis_prompt(content: str, target_llm: str = "General AI Assistant") -> str:
    """
    Get the analysis system prompt with content filled in

    Args:
        content: The prompt content to analyze
        target_llm: The target LLM platform

    Returns:
        Formatted system prompt for analysis
    """
    return ANALYSIS_SYSTEM_PROMPT.format(
        content=content,
        target_llm=target_llm or "General AI Assistant"
    )


def get_enhancement_prompt(content: str, target_llm: str = "AI language models") -> str:
    """
    Get the enhancement system prompt with content filled in

    Args:
        content: The prompt content to enhance
        target_llm: The target LLM platform

    Returns:
        Formatted system prompt for enhancement
    """
    return ENHANCEMENT_SYSTEM_PROMPT.format(
        content=content,
        target_llm=target_llm or "AI language models"
    )


def get_versions_prompt(
    content: str,
    target_llm: str = "AI language models",
    num_versions: int = 3
) -> str:
    """
    Get the versions generation system prompt with content filled in

    Args:
        content: The prompt content to create versions for
        target_llm: The target LLM platform
        num_versions: Number of versions to generate

    Returns:
        Formatted system prompt for version generation
    """
    return VERSIONS_SYSTEM_PROMPT.format(
        content=content,
        target_llm=target_llm or "AI language models",
        num_versions=num_versions
    )


def get_ambiguity_prompt(content: str) -> str:
    """
    Get the ambiguity detection system prompt with content filled in

    Args:
        content: The prompt content to analyze for ambiguities

    Returns:
        Formatted system prompt for ambiguity detection
    """
    return AMBIGUITY_DETECTION_PROMPT.format(content=content)


def get_best_practices(target_llm: str) -> list:
    """
    Get best practices for a specific LLM

    Args:
        target_llm: The target LLM platform

    Returns:
        List of best practice recommendations
    """
    return BEST_PRACTICES_MAP.get(target_llm, BEST_PRACTICES_MAP["ChatGPT"])
