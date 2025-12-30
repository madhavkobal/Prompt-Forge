import google.generativeai as genai
from typing import Dict, Any, List, Optional, Tuple
import json
import re
import time
import hashlib
from app.core.config import settings
from app.core.exceptions import AnalysisUnavailableException, EnhancementUnavailableException
from app.config.system_prompts import (
    get_analysis_prompt,
    get_enhancement_prompt,
    get_versions_prompt,
    get_ambiguity_prompt,
    get_best_practices,
    BEST_PRACTICES_MAP,
)
from app.schemas.prompt import PromptAnalysis, PromptEnhancement

# Configure Gemini API
genai.configure(api_key=settings.GEMINI_API_KEY)


class GeminiService:
    """Service for Google Gemini API integration with retry logic, caching, and multiple model support"""

    # Supported Gemini models
    SUPPORTED_MODELS = {
        'gemini-pro': 'gemini-pro',
        'gemini-1.5-pro': 'gemini-1.5-pro-latest',
        'gemini-1.5-flash': 'gemini-1.5-flash-latest',
    }

    # Cache TTL in seconds (1 hour)
    CACHE_TTL = 3600

    def __init__(self, model_name: str = 'gemini-pro', max_retries: int = 3):
        """
        Initialize Gemini service with caching

        Args:
            model_name: Name of the Gemini model to use
            max_retries: Maximum number of retry attempts for API calls
        """
        self.model_name = self.SUPPORTED_MODELS.get(model_name, 'gemini-pro')
        self.model = genai.GenerativeModel(self.model_name)
        self.max_retries = max_retries

        # In-memory cache: {cache_key: (result, expiry_timestamp)}
        self._cache: Dict[str, Tuple[Any, float]] = {}
        self._last_cleanup = time.time()

    def _get_cache_key(self, content: str, target_llm: Optional[str], operation: str) -> str:
        """
        Generate cache key from content and parameters

        Args:
            content: The prompt content
            target_llm: Target LLM platform
            operation: Type of operation (analyze, enhance, etc.)

        Returns:
            SHA256 hash as cache key
        """
        cache_str = f"{operation}:{content}:{target_llm or 'general'}"
        return hashlib.sha256(cache_str.encode()).hexdigest()

    def _get_from_cache(self, cache_key: str) -> Optional[Any]:
        """
        Retrieve item from cache if not expired

        Args:
            cache_key: The cache key to look up

        Returns:
            Cached result or None if not found/expired
        """
        if cache_key in self._cache:
            result, expiry = self._cache[cache_key]
            if time.time() < expiry:
                return result
            else:
                # Expired - remove it
                del self._cache[cache_key]
        return None

    def _save_to_cache(self, cache_key: str, result: Any) -> None:
        """
        Save result to cache with TTL

        Args:
            cache_key: The cache key
            result: The result to cache
        """
        expiry = time.time() + self.CACHE_TTL
        self._cache[cache_key] = (result, expiry)

        # Periodic cleanup of expired entries (every 10 minutes)
        if time.time() - self._last_cleanup > 600:
            self._cleanup_expired_cache()

    def _cleanup_expired_cache(self) -> None:
        """Remove expired entries from cache to prevent memory bloat"""
        current_time = time.time()
        expired_keys = [
            key for key, (_, expiry) in self._cache.items()
            if current_time >= expiry
        ]
        for key in expired_keys:
            del self._cache[key]
        self._last_cleanup = current_time

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
        Analyze prompt quality with detailed evaluation (with caching)

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

        Raises:
            AnalysisUnavailableException: If analysis service fails
        """
        # Check cache first
        cache_key = self._get_cache_key(content, target_llm, "analyze")
        cached_result = self._get_from_cache(cache_key)
        if cached_result is not None:
            return cached_result

        analysis_prompt = get_analysis_prompt(content, target_llm)

        try:
            response_text = self._make_request_with_retry(analysis_prompt)
            result = self._parse_analysis_response(response_text)
            analysis = PromptAnalysis(**result)

            # Save to cache
            self._save_to_cache(cache_key, analysis)

            return analysis
        except Exception as e:
            error_msg = str(e)
            print(f"Error in analyze_prompt: {error_msg}")
            raise AnalysisUnavailableException(details=error_msg)

    def enhance_prompt(self, content: str, target_llm: Optional[str] = None) -> PromptEnhancement:
        """
        Enhance the prompt with best practices - generates multiple improved versions (with caching)

        Args:
            content: The original prompt content
            target_llm: Target LLM for optimization

        Returns:
            PromptEnhancement with 2-3 improved versions and explanations

        Raises:
            EnhancementUnavailableException: If enhancement service fails
        """
        # Check cache first
        cache_key = self._get_cache_key(content, target_llm, "enhance")
        cached_result = self._get_from_cache(cache_key)
        if cached_result is not None:
            return cached_result

        enhancement_prompt = get_enhancement_prompt(content, target_llm)

        try:
            response_text = self._make_request_with_retry(enhancement_prompt)
            result = self._parse_enhancement_response(response_text, content)
            enhancement = PromptEnhancement(**result)

            # Save to cache
            self._save_to_cache(cache_key, enhancement)

            return enhancement
        except Exception as e:
            error_msg = str(e)
            print(f"Error in enhance_prompt: {error_msg}")
            raise EnhancementUnavailableException(details=error_msg)

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

        Raises:
            EnhancementUnavailableException: If version generation fails
        """
        versions_prompt = get_versions_prompt(content, target_llm, num_versions)

        try:
            response_text = self._make_request_with_retry(versions_prompt)
            result = self._parse_json_response(response_text)
            return result.get("versions", [])
        except Exception as e:
            error_msg = str(e)
            print(f"Error in generate_prompt_versions: {error_msg}")
            raise EnhancementUnavailableException(details=error_msg)

    def detect_ambiguities(self, content: str) -> List[Dict[str, str]]:
        """
        Detect ambiguous or unclear parts of a prompt

        Args:
            content: The prompt content to analyze

        Returns:
            List of detected ambiguities with suggestions

        Raises:
            AnalysisUnavailableException: If ambiguity detection fails
        """
        ambiguity_prompt = get_ambiguity_prompt(content)

        try:
            response_text = self._make_request_with_retry(ambiguity_prompt)
            result = self._parse_json_response(response_text)
            return result.get("ambiguities", [])
        except Exception as e:
            error_msg = str(e)
            print(f"Error in detect_ambiguities: {error_msg}")
            raise AnalysisUnavailableException(details=error_msg)

    def check_best_practices(self, content: str, target_llm: str) -> Dict[str, Any]:
        """Check prompt against LLM-specific best practices"""
        practices = get_best_practices(target_llm)

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
        """
        Parse Gemini response for analysis

        Raises:
            Exception: If parsing fails (will be caught and re-raised as AnalysisUnavailableException)
        """
        result = self._parse_json_response(response_text)

        # Ensure all required fields are present with reasonable defaults
        required_fields = {
            "quality_score": 0.0,
            "clarity_score": 0.0,
            "specificity_score": 0.0,
            "structure_score": 0.0,
            "strengths": [],
            "weaknesses": [],
            "suggestions": [],
            "best_practices": {}
        }

        for field, default in required_fields.items():
            if field not in result:
                result[field] = default

        return result

    def _parse_enhancement_response(self, response_text: str, original: str) -> Dict[str, Any]:
        """
        Parse Gemini response for enhancement

        Raises:
            Exception: If parsing fails (will be caught and re-raised as EnhancementUnavailableException)
        """
        result = self._parse_json_response(response_text)
        result["original_content"] = original

        # Ensure required fields - if missing, raise exception
        if "enhanced_content" not in result:
            raise ValueError("Response missing 'enhanced_content' field")
        if "improvements" not in result:
            result["improvements"] = []
        if "quality_improvement" not in result:
            result["quality_improvement"] = 0.0

        return result

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
