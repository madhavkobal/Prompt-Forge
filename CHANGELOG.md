# Changelog

All notable changes to PromptForge will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `.nvmrc` file for Node.js version pinning (v20 LTS)
- Pre-commit hooks configuration with linting and security checks
- Dependabot configuration for automatic dependency updates
- Frontend Docker container healthcheck
- This CHANGELOG file to track project changes

## [1.1.0] - 2025-12-30

### Added
- **Rate Limiting UX**: User-friendly 429 error handling with retry countdown toast notifications
- **Dark Mode Support**: PromptEditor now supports light/dark/auto themes with system preference detection
- **In-Memory Caching**: 1-hour TTL cache for Gemini API responses to reduce costs and improve performance
- **Prompt Versioning System**: Database tracking of meta-prompt versions for A/B testing and analytics
- Database migration for `system_prompts_version` column
- Comprehensive PR description templates

### Changed
- Updated `frontend/src/utils/api.ts` to handle 429 rate limit responses
- Enhanced `frontend/src/components/PromptEditor.tsx` with dynamic theme switching
- Improved `backend/app/services/gemini_service.py` with caching infrastructure
- Modified `backend/app/api/prompts.py` to track system prompts version

### Fixed
- CodeQL security scan timeout issues by optimizing query set

## [1.0.0] - 2025-12-28

### Added
- **System Prompts Configuration**: Extracted hardcoded meta-prompts to `backend/app/config/system_prompts.py`
- **Custom Exception Handling**: `AnalysisUnavailableException` and `EnhancementUnavailableException`
- **Session Expiry Handling**: Graceful 401 handling with SessionMonitor component
- **Security Hardening**: Production safety checks for SECRET_KEY and CORS_ORIGINS

### Changed
- Replaced fake fallback data with proper HTTP 503 error responses
- Updated `frontend/src/utils/api.ts` to use `authStore.handleSessionExpiry()` instead of hard reload
- Implemented explicit field mapping in `backend/app/api/prompts.py` for update security

### Removed
- Fake analysis scores (quality_score=60) when Gemini API fails
- Hardcoded system prompts from `gemini_service.py`

### Fixed
- Docker Compose database name mismatch (`promptforge_db` → `promptforge`)
- Logging KeyError crashes by removing `rename_fields` parameter
- Docker deployment issues for headless server remote access
- Session state loss on authentication expiry

### Security
- Added SECRET_KEY validation in production mode
- Added CORS wildcard validation to prevent insecure configurations
- Implemented explicit field mapping to prevent field overwrites

## [0.9.0] - 2025-12-27

### Added
- Initial project setup
- FastAPI backend with PostgreSQL database
- React + TypeScript frontend with Vite
- Google Gemini AI integration
- User authentication with JWT
- Prompt analysis and enhancement features
- Docker Compose deployment configuration
- Ubuntu installation scripts
- Comprehensive documentation

### Infrastructure
- PostgreSQL database with Alembic migrations
- Prometheus metrics integration
- Structured logging with custom JSON formatter
- Sentry error tracking support
- Health check endpoints
- Rate limiting middleware

---

## Version Naming Convention

- **Major version** (x.0.0): Breaking changes, major features
- **Minor version** (0.x.0): New features, backward compatible
- **Patch version** (0.0.x): Bug fixes, security patches

## Links

- [GitHub Repository](https://github.com/madhavkobal/Prompt-Forge)
- [Issue Tracker](https://github.com/madhavkobal/Prompt-Forge/issues)
- [Pull Requests](https://github.com/madhavkobal/Prompt-Forge/pulls)

[Unreleased]: https://github.com/madhavkobal/Prompt-Forge/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/madhavkobal/Prompt-Forge/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/madhavkobal/Prompt-Forge/compare/v0.9.0...v1.0.0
[0.9.0]: https://github.com/madhavkobal/Prompt-Forge/releases/tag/v0.9.0
