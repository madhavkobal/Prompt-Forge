"""
Custom exceptions for PromptForge
"""


class PromptForgeException(Exception):
    """Base exception for PromptForge"""
    pass


class AIServiceException(PromptForgeException):
    """Exception raised when AI service (Gemini) fails"""

    def __init__(self, message: str = "AI analysis service is temporarily unavailable", details: str = None):
        self.message = message
        self.details = details
        super().__init__(self.message)


class AnalysisUnavailableException(AIServiceException):
    """Exception raised when prompt analysis fails"""

    def __init__(self, details: str = None):
        super().__init__(
            message="Prompt analysis is currently unavailable. Please try again later.",
            details=details
        )


class EnhancementUnavailableException(AIServiceException):
    """Exception raised when prompt enhancement fails"""

    def __init__(self, details: str = None):
        super().__init__(
            message="Prompt enhancement is currently unavailable. Please try again later.",
            details=details
        )


class RateLimitException(PromptForgeException):
    """Exception raised when rate limit is exceeded"""

    def __init__(self, retry_after: int = None):
        self.retry_after = retry_after
        message = "Rate limit exceeded. Please try again later."
        if retry_after:
            message = f"Rate limit exceeded. Please try again in {retry_after} seconds."
        super().__init__(message)


class ValidationException(PromptForgeException):
    """Exception raised when validation fails"""
    pass
