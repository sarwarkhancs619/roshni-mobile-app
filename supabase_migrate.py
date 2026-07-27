import os
import sys
import getpass

# 1. Self-installer for dependencies
try:
    import psycopg2
except ImportError:
    print("psycopg2-binary not found. Installing now...")
    import subprocess
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary"])
        import psycopg2
    except Exception as e:
        print(f"Failed to auto-install psycopg2: {e}")
        print("Please run: pip install psycopg2-binary")
        sys.exit(1)

def run_migration():
    # Load .env file manually if exists
    env_url = ""
    if os.path.exists(".env"):
        with open(".env", "r") as f:
            for line in f:
                if line.startswith("SUPABASE_DB_URL="):
                    env_url = line.split("=", 1)[1].strip()

    # Base URL configuration
    base_url = "postgresql://postgres:[YOUR-PASSWORD]@db.mvglzjkehfxasydgugoq.supabase.co:5432/postgres"
    if env_url:
        base_url = env_url

    connection_url = base_url
    if "[YOUR-PASSWORD]" in base_url or "YOUR_ACTUAL_PASSWORD" in base_url:
        print("\n--- Supabase Database Migration Tool ---")
        print(f"Target DB Host: db.mvglzjkehfxasydgugoq.supabase.co")
        password = getpass.getpass("Enter your Supabase Database Password: ")
        connection_url = base_url.replace("[YOUR-PASSWORD]", password).replace("YOUR_ACTUAL_PASSWORD", password)

    # Load SQL Schema file
    if not os.path.exists("supabase_schema.sql"):
        print("Error: supabase_schema.sql not found in workspace root.")
        sys.exit(1)

    with open("supabase_schema.sql", "r") as sql_file:
        sql_script = sql_file.read()

    print("\nConnecting to Supabase PostgreSQL database...")
    try:
        conn = psycopg2.connect(connection_url)
        conn.autocommit = True
        cursor = conn.cursor()

        print("Executing schema script DDL commands...")
        # Split by command sections to execute
        cursor.execute(sql_script)

        print("\n[SUCCESS] Supabase tables created successfully!")
        cursor.close()
        conn.close()
    except Exception as err:
        print(f"\n[ERROR] Database Migration failed: {err}")
        sys.exit(1)

if __name__ == "__main__":
    run_migration()
