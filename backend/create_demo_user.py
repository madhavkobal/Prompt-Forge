#!/usr/bin/env python3
"""
Quick script to create a demo user for PromptForge

Usage:
    python create_demo_user.py
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import get_password_hash


def create_demo_user():
    """Create or update demo user account"""
    db = SessionLocal()

    try:
        # Check if user exists
        existing_user = db.query(User).filter(User.username == "demo").first()

        if existing_user:
            print("ℹ️  Demo user already exists")
            print("🔄 Updating password...")
            existing_user.hashed_password = get_password_hash("DemoPassword123!")
            existing_user.is_active = True
            db.commit()
            print("✅ Demo user password updated")
        else:
            print("👤 Creating demo user...")
            demo_user = User(
                email="demo@promptforge.io",
                username="demo",
                full_name="Demo User",
                hashed_password=get_password_hash("DemoPassword123!"),
                is_active=True
            )
            db.add(demo_user)
            db.commit()
            print("✅ Demo user created successfully")

        print("\n" + "="*50)
        print("📧 Email: demo@promptforge.io")
        print("👤 Username: demo")
        print("🔑 Password: DemoPassword123!")
        print("="*50)

    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    create_demo_user()
