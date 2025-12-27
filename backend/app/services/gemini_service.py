import google.generativeai as genai
from typing import Dict, Any, List
from app.core.config import settings
from app.schemas.prompt import PromptAnalysis, PromptEnhancement

# Configure Gemini API
genai.configure(api_key=settings.GEMINI_API_KEY)


class GeminiService:
    def __init__(self):
        self.model = genai.GenerativeModel('gemini-pro')

    def analyze_prompt(self, content: str, target_llm: str = None) -> PromptAnalysis:
        """Analyze prompt quality and provide detailed feedback"""
        analysis_prompt = f"""
Analyze the following prompt for quality, clarity, specificity, and structure.
Provide a detailed analysis with scores (0-100) and actionable suggestions.

Target LLM: {target_llm or 'General'}

Prompt to analyze:
{content}

Provide your analysis in the following JSON format:
{{
    "quality_score": <0-100>,
    "clarity_score": <0-100>,
    "specificity_score": <0-100>,
    "structure_score": <0-100>,
    "strengths": ["strength1", "strength2", ...],
    "weaknesses": ["weakness1", "weakness2", ...],
    "suggestions": ["suggestion1", "suggestion2", ...],
    "best_practices": {{
        "context": "assessment of context provision",
        "role_definition": "assessment of role clarity",
        "output_format": "assessment of output format specification",
        "constraints": "assessment of constraints definition"
    }}
}}
"""

        try:
            response = self.model.generate_content(analysis_prompt)
            # Parse the response - in production, add proper JSON extraction
            result = self._parse_analysis_response(response.text)
            return PromptAnalysis(**result)
        except Exception as e:
            # Fallback analysis
            return self._fallback_analysis(content)

    def enhance_prompt(self, content: str, target_llm: str = None) -> PromptEnhancement:
        """Enhance the prompt with best practices"""
        enhancement_prompt = f"""
Enhance the following prompt using best practices for {target_llm or 'AI language models'}.
Make it more specific, clear, and effective while maintaining the original intent.

Original prompt:
{content}

Provide your response in the following JSON format:
{{
    "enhanced_content": "the improved prompt",
    "improvements": ["improvement1", "improvement2", ...],
    "quality_improvement": <estimated percentage improvement>
}}
"""

        try:
            response = self.model.generate_content(enhancement_prompt)
            result = self._parse_enhancement_response(response.text, content)
            return PromptEnhancement(**result)
        except Exception as e:
            # Fallback enhancement
            return self._fallback_enhancement(content)

    def check_best_practices(self, content: str, target_llm: str) -> Dict[str, Any]:
        """Check prompt against LLM-specific best practices"""
        best_practices_map = {
            "ChatGPT": [
                "Use clear role definitions",
                "Provide context and background",
                "Specify output format",
                "Break complex tasks into steps",
                "Use examples when helpful",
            ],
            "Claude": [
                "Structure with XML tags when appropriate",
                "Be explicit about constraints",
                "Use chain-of-thought prompting",
                "Provide clear success criteria",
                "Leverage Claude's analytical strengths",
            ],
            "Gemini": [
                "Leverage multimodal capabilities",
                "Use structured output formats",
                "Provide clear context",
                "Specify reasoning requirements",
                "Use iterative refinement",
            ],
            "Grok": [
                "Be direct and specific",
                "Leverage real-time knowledge",
                "Use clear formatting",
                "Provide explicit instructions",
            ],
            "DeepSeek": [
                "Focus on reasoning tasks",
                "Provide step-by-step guidance",
                "Use clear problem structure",
                "Leverage analytical capabilities",
            ],
        }

        practices = best_practices_map.get(target_llm, best_practices_map["ChatGPT"])

        # Analyze compliance with best practices
        compliance_check = {
            "target_llm": target_llm,
            "best_practices": practices,
            "compliance_score": self._calculate_compliance(content, practices),
            "recommendations": self._generate_recommendations(content, practices),
        }

        return compliance_check

    def _parse_analysis_response(self, response_text: str) -> Dict[str, Any]:
        """Parse Gemini response for analysis"""
        # Extract JSON from response (handle markdown code blocks)
        import json
        import re

        json_match = re.search(r'```json\n(.*?)\n```', response_text, re.DOTALL)
        if json_match:
            json_str = json_match.group(1)
        else:
            json_str = response_text

        try:
            return json.loads(json_str)
        except:
            return self._fallback_analysis_dict()

    def _parse_enhancement_response(self, response_text: str, original: str) -> Dict[str, Any]:
        """Parse Gemini response for enhancement"""
        import json
        import re

        json_match = re.search(r'```json\n(.*?)\n```', response_text, re.DOTALL)
        if json_match:
            json_str = json_match.group(1)
        else:
            json_str = response_text

        try:
            result = json.loads(json_str)
            result["original_content"] = original
            return result
        except:
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
            "weaknesses": ["Could not parse analysis"],
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

    def _calculate_compliance(self, content: str, practices: List[str]) -> float:
        """Calculate compliance score with best practices"""
        # Simple heuristic-based compliance check
        score = 50.0  # Base score

        content_lower = content.lower()

        # Check for various indicators
        if len(content) > 100:
            score += 10
        if ":" in content or "?" in content:
            score += 10
        if any(word in content_lower for word in ["please", "specific", "detailed"]):
            score += 10
        if len(content.split()) > 20:
            score += 10
        if "\n" in content:
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

        # Add general recommendations from best practices
        recommendations.extend(practices[:3])

        return recommendations
