import google.generativeai as genai
from typing import Dict, Any, List, Optional
import json
import re
import time
from app.core.config import settings
from app.schemas.prompt import PromptAnalysis, PromptEnhancement

# Configure Gemini API
genai.configure(api_key=settings.GEMINI_API_KEY)


class GeminiService:
    """Service for Google Gemini API integration with retry logic and multiple model support"""

    # Supported Gemini models
    SUPPORTED_MODELS = {
        'gemini-pro': 'gemini-pro',
        'gemini-1.5-pro': 'gemini-1.5-pro-latest',
        'gemini-1.5-flash': 'gemini-1.5-flash-latest',
    }

    def __init__(self, model_name: str = 'gemini-pro', max_retries: int = 3):
        """
        Initialize Gemini service

        Args:
            model_name: Name of the Gemini model to use
            max_retries: Maximum number of retry attempts for API calls
        """
        self.model_name = self.SUPPORTED_MODELS.get(model_name, 'gemini-pro')
        self.model = genai.GenerativeModel(self.model_name)
        self.max_retries = max_retries

    def _make_request_with_retry(self, prompt: str) -> str:
        """
        Make API request with exponential backoff retry logic

        Args:
            prompt: The prompt to send to Gemini

        Returns:
            Response text from Gemini

        Raises:
            Exception: If all retry attempts fail
        """
        last_exception = None

        for attempt in range(self.max_retries):
            try:
                response = self.model.generate_content(prompt)
                return response.text
            except Exception as e:
                last_exception = e

                # Don't retry on certain errors
                if "API_KEY" in str(e) or "authentication" in str(e).lower():
                    raise

                # Exponential backoff: 2^attempt seconds (1s, 2s, 4s)
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt
                    time.sleep(wait_time)

        # All retries failed
        raise Exception(f"Failed after {self.max_retries} attempts: {last_exception}")

    def analyze_prompt(self, content: str, target_llm: Optional[str] = None) -> PromptAnalysis:
        """
        Analyze prompt quality with detailed evaluation

        Evaluates:
        - Clarity score (0-100)
        - Specificity score (0-100)
        - Structure score (0-100)
        - Context completeness
        - Ambiguity detection

        Args:
            content: The prompt content to analyze
            target_llm: Target LLM for best practices (ChatGPT, Claude, Gemini, etc.)

        Returns:
            PromptAnalysis with scores and detailed feedback
        """
        analysis_prompt = f"""
You are an expert prompt engineer. Analyze the following prompt for quality and provide detailed feedback.

Target LLM: {target_llm or 'General AI Assistant'}

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

        try:
            response_text = self._make_request_with_retry(analysis_prompt)
            result = self._parse_analysis_response(response_text)
            return PromptAnalysis(**result)
        except Exception as e:
            print(f"Error in analyze_prompt: {e}")
            return self._fallback_analysis(content)

    def enhance_prompt(self, content: str, target_llm: Optional[str] = None) -> PromptEnhancement:
        """
        Enhance the prompt with best practices - generates multiple improved versions

        Args:
            content: The original prompt content
            target_llm: Target LLM for optimization

        Returns:
            PromptEnhancement with 2-3 improved versions and explanations
        """
        enhancement_prompt = f"""
You are an expert prompt engineer. Enhance the following prompt for {target_llm or 'AI language models'}.

Original prompt:
\"\"\"
{content}
\"\"\"

Create an improved version that:
1. Adds necessary context and background
2. Makes requirements more specific and clear
3. Structures the prompt better
4. Removes ambiguities
5. Follows best practices for {target_llm or 'AI assistants'}

Maintain the original intent but make it significantly more effective.

Respond in STRICT JSON format (no markdown, no extra text):
{{
    "enhanced_content": "the single best improved version of the prompt",
    "improvements": ["specific improvement 1", "specific improvement 2", "..."],
    "quality_improvement": <estimated percentage improvement as number>
}}
"""

        try:
            response_text = self._make_request_with_retry(enhancement_prompt)
            result = self._parse_enhancement_response(response_text, content)
            return PromptEnhancement(**result)
        except Exception as e:
            print(f"Error in enhance_prompt: {e}")
            return self._fallback_enhancement(content)

    def generate_prompt_versions(
        self,
        content: str,
        target_llm: Optional[str] = None,
        num_versions: int = 3
    ) -> List[Dict[str, Any]]:
        """
        Generate multiple enhanced versions of a prompt

        Args:
            content: Original prompt content
            target_llm: Target LLM for optimization
            num_versions: Number of versions to generate (2-3)

        Returns:
            List of enhanced prompt versions with explanations
        """
        versions_prompt = f"""
You are an expert prompt engineer. Create {num_versions} different enhanced versions of the following prompt for {target_llm or 'AI language models'}.

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

        try:
            response_text = self._make_request_with_retry(versions_prompt)
            result = self._parse_json_response(response_text)
            return result.get("versions", [])
        except Exception as e:
            print(f"Error in generate_prompt_versions: {e}")
            return self._fallback_versions(content, num_versions)

    def detect_ambiguities(self, content: str) -> List[Dict[str, str]]:
        """
        Detect ambiguous or unclear parts of a prompt

        Args:
            content: The prompt content to analyze

        Returns:
            List of detected ambiguities with suggestions
        """
        ambiguity_prompt = f"""
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

        try:
            response_text = self._make_request_with_retry(ambiguity_prompt)
            result = self._parse_json_response(response_text)
            return result.get("ambiguities", [])
        except Exception as e:
            print(f"Error in detect_ambiguities: {e}")
            return []

    def check_best_practices(self, content: str, target_llm: str) -> Dict[str, Any]:
        """Check prompt against LLM-specific best practices"""
        best_practices_map = {
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

        practices = best_practices_map.get(target_llm, best_practices_map["ChatGPT"])

        compliance_check = {
            "target_llm": target_llm,
            "best_practices": practices,
            "compliance_score": self._calculate_compliance(content, practices),
            "recommendations": self._generate_recommendations(content, practices),
        }

        return compliance_check

    def _parse_json_response(self, response_text: str) -> Dict[str, Any]:
        """
        Parse JSON from Gemini response, handling various formats

        Args:
            response_text: Raw response from Gemini

        Returns:
            Parsed JSON as dictionary
        """
        # Try to extract JSON from markdown code blocks
        json_match = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', response_text, re.DOTALL)
        if json_match:
            json_str = json_match.group(1).strip()
        else:
            json_str = response_text.strip()

        # Remove any leading/trailing whitespace and newlines
        json_str = json_str.strip()

        # Try to find JSON object in the text
        if not json_str.startswith('{'):
            json_match = re.search(r'\{.*\}', json_str, re.DOTALL)
            if json_match:
                json_str = json_match.group(0)

        try:
            return json.loads(json_str)
        except json.JSONDecodeError as e:
            print(f"JSON parsing error: {e}")
            print(f"Attempted to parse: {json_str[:200]}...")
            raise

    def _parse_analysis_response(self, response_text: str) -> Dict[str, Any]:
        """Parse Gemini response for analysis"""
        try:
            result = self._parse_json_response(response_text)

            # Ensure all required fields are present
            required_fields = {
                "quality_score": 60.0,
                "clarity_score": 60.0,
                "specificity_score": 60.0,
                "structure_score": 60.0,
                "strengths": ["Prompt provided"],
                "weaknesses": ["Analysis incomplete"],
                "suggestions": ["Review prompt"],
                "best_practices": {}
            }

            for field, default in required_fields.items():
                if field not in result:
                    result[field] = default

            return result
        except Exception as e:
            print(f"Error parsing analysis response: {e}")
            return self._fallback_analysis_dict()

    def _parse_enhancement_response(self, response_text: str, original: str) -> Dict[str, Any]:
        """Parse Gemini response for enhancement"""
        try:
            result = self._parse_json_response(response_text)
            result["original_content"] = original

            # Ensure required fields
            if "enhanced_content" not in result:
                result["enhanced_content"] = original
            if "improvements" not in result:
                result["improvements"] = []
            if "quality_improvement" not in result:
                result["quality_improvement"] = 0.0

            return result
        except Exception as e:
            print(f"Error parsing enhancement response: {e}")
            return self._fallback_enhancement_dict(original)

    def _fallback_analysis(self, content: str) -> PromptAnalysis:
        """Provide fallback analysis if API fails"""
        return PromptAnalysis(
            quality_score=60.0,
            clarity_score=65.0,
            specificity_score=55.0,
            structure_score=60.0,
            strengths=["Prompt provided"],
            weaknesses=["Analysis service temporarily unavailable"],
            suggestions=["Try again later for detailed analysis"],
            best_practices={},
        )

    def _fallback_analysis_dict(self) -> Dict[str, Any]:
        """Fallback analysis dictionary"""
        return {
            "quality_score": 60.0,
            "clarity_score": 65.0,
            "specificity_score": 55.0,
            "structure_score": 60.0,
            "strengths": ["Prompt provided"],
            "weaknesses": ["Could not parse analysis response"],
            "suggestions": ["Review prompt manually"],
            "best_practices": {},
        }

    def _fallback_enhancement(self, content: str) -> PromptEnhancement:
        """Provide fallback enhancement if API fails"""
        return PromptEnhancement(
            original_content=content,
            enhanced_content=content,
            improvements=["Enhancement service temporarily unavailable"],
            quality_improvement=0.0,
        )

    def _fallback_enhancement_dict(self, content: str) -> Dict[str, Any]:
        """Fallback enhancement dictionary"""
        return {
            "original_content": content,
            "enhanced_content": content,
            "improvements": ["Could not generate enhancement"],
            "quality_improvement": 0.0,
        }

    def _fallback_versions(self, content: str, num_versions: int) -> List[Dict[str, Any]]:
        """Fallback versions if API fails"""
        return [
            {
                "version_number": i + 1,
                "title": f"Version {i + 1}",
                "enhanced_content": content,
                "improvements": ["Service temporarily unavailable"],
                "focus": "unavailable"
            }
            for i in range(num_versions)
        ]

    def _calculate_compliance(self, content: str, practices: List[str]) -> float:
        """Calculate compliance score with best practices"""
        score = 40.0  # Base score
        content_lower = content.lower()

        # Length checks
        if len(content) > 100:
            score += 10
        if len(content.split()) > 20:
            score += 10

        # Structure checks
        if ":" in content or "?" in content:
            score += 10
        if "\n" in content:
            score += 10

        # Quality indicators
        quality_words = ["please", "specific", "detailed", "explain", "describe", "analyze"]
        if any(word in content_lower for word in quality_words):
            score += 10

        # Role definition
        if "you are" in content_lower or "act as" in content_lower:
            score += 10

        return min(score, 100.0)

    def _generate_recommendations(self, content: str, practices: List[str]) -> List[str]:
        """Generate recommendations based on best practices"""
        recommendations = []

        if len(content) < 50:
            recommendations.append("Add more context and details to your prompt")
        if "?" not in content:
            recommendations.append("Consider framing your request as a clear question")
        if not any(char.isupper() for char in content):
            recommendations.append("Use proper capitalization for clarity")
        if "\n" not in content and len(content) > 100:
            recommendations.append("Break long prompts into paragraphs or bullet points")

        # Add top best practices
        recommendations.extend(practices[:3])

        return recommendations
