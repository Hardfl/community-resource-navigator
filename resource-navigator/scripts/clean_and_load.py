"""
clean_and_load.py
-----------------
Community Resource Navigator — data pipeline

What this script does:
  1. Reads raw service data from CSV (messy, real-world format)
  2. Cleans and standardizes it with Pandas
  3. Flags data quality issues and missing fields
  4. Loads clean data into SQLite
  5. Runs gap analysis on search logs
  6. Outputs a summary report

Usage:
  python scripts/clean_and_load.py

Requirements:
  pip install pandas sqlite3  (sqlite3 is built into Python)
"""

import sqlite3
import os
import re
import pandas as pd
from datetime import datetime, date


# ── CONFIG ──────────────────────────────────────────────────

DB_PATH      = "resources.db"
SCHEMA_PATH  = "sql/schema.sql"
RAW_CSV      = "data/resources_raw.csv"
LOGS_CSV     = "data/search_logs.csv"
CLEAN_CSV    = "data/resources_clean.csv"
REPORT_PATH  = "data/gap_report.txt"


# ── STEP 1: LOAD AND CLEAN RAW DATA ─────────────────────────

def clean_resources(path: str) -> pd.DataFrame:
    print("\n── Loading raw data ──────────────────────────")
    df = pd.read_csv(path)
    print(f"  Loaded {len(df)} rows, {len(df.columns)} columns")
    print(f"  Columns: {list(df.columns)}\n")

    original_count = len(df)

    # Drop rows with no org name (completely empty records)
    df = df.dropna(subset=["org_name"])
    dropped = original_count - len(df)
    if dropped:
        print(f"  ⚠  Dropped {dropped} rows with missing org_name")

    # Standardize category: lowercase + strip whitespace
    df["category"] = df["category"].str.strip().str.lower()

    # Fix known category typos / variants
    category_map = {
        "housing": "housing",
        "food": "food",
        "health": "health",
        "environment": "environment",
        "humanitarian": "humanitarian",
    }
    before = df["category"].copy()
    df["category"] = df["category"].map(category_map).fillna(df["category"])
    changed = (before != df["category"]).sum()
    if changed:
        print(f"  ✓  Standardized {changed} category values")

    # Standardize phone: strip non-digit chars, reformat as XXX-XXXX
    def clean_phone(p):
        if pd.isna(p):
            return None
        digits = re.sub(r"\D", "", str(p))
        if len(digits) == 7:
            return f"{digits[:3]}-{digits[3:]}"
        elif len(digits) == 10:
            return f"({digits[:3]}) {digits[3:6]}-{digits[6:]}"
        return str(p).strip()  # return as-is if unrecognized format

    df["phone"] = df["phone"].apply(clean_phone)

    # Strip whitespace from text fields
    text_cols = ["org_name", "service_description", "eligibility", "address", "hours"]
    for col in text_cols:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip()
            df[col] = df[col].replace("nan", None)

    # Parse and validate last_verified dates
    def parse_date(d):
        if pd.isna(d) or d in ("", "nan", None):
            return None
        try:
            return pd.to_datetime(d).date().isoformat()
        except Exception:
            return None

    df["last_verified"] = df["last_verified"].apply(parse_date)

    # Flag stale records (not verified in 90+ days)
    today = date.today()
    def is_stale(d):
        if not d:
            return True
        try:
            delta = today - date.fromisoformat(d)
            return delta.days > 90
        except Exception:
            return True

    df["stale"] = df["last_verified"].apply(is_stale)
    stale_count = df["stale"].sum()
    print(f"  ⚠  {stale_count} records have stale or missing verification dates (>90 days)")

    print(f"\n  Clean dataset: {len(df)} rows ready to load")
    return df


# ── STEP 2: DATA QUALITY REPORT ─────────────────────────────

def quality_report(df: pd.DataFrame) -> dict:
    print("\n── Data quality report ───────────────────────")
    total = len(df)
    fields = {
        "org_name":            "Organization name",
        "service_description": "Service description",
        "eligibility":         "Eligibility criteria",
        "phone":               "Phone number",
        "address":             "Address",
        "capacity":            "Capacity / slots",
        "lat":                 "GPS latitude",
        "lng":                 "GPS longitude",
    }
    report = {}
    for col, label in fields.items():
        if col in df.columns:
            filled = df[col].notna().sum()
            pct = round(100 * filled / total, 1)
            report[label] = pct
            flag = "✓" if pct >= 80 else "⚠ "
            print(f"  {flag}  {label:<28} {pct:>5}% complete  ({filled}/{total})")
    return report


# ── STEP 3: LOAD INTO SQLITE ─────────────────────────────────

def init_database(db_path: str, schema_path: str) -> sqlite3.Connection:
    print(f"\n── Setting up database: {db_path} ───────────")
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    with open(schema_path, "r") as f:
        schema_sql = f.read()
    # Strip SQL comments (-- lines) so split on ; works cleanly
    lines = [l for l in schema_sql.splitlines() if not l.strip().startswith("--")]
    clean_sql = "\n".join(lines)
    statements = [s.strip() for s in clean_sql.split(";") if s.strip()]
    for stmt in statements:
        first_word = stmt.strip().upper().split()[0] if stmt.strip() else ""
        if first_word in ("CREATE",):
            try:
                conn.execute(stmt)
            except sqlite3.OperationalError:
                pass  # Table/index already exists — safe to skip
    conn.commit()
    print("  ✓  Schema initialized")
    return conn


def load_organizations(conn: sqlite3.Connection, df: pd.DataFrame):
    print("\n── Loading organizations ─────────────────────")
    cursor = conn.cursor()

    # Clear existing data for a clean reload (idempotent script)
    cursor.execute("DELETE FROM eligibility")
    cursor.execute("DELETE FROM services")
    cursor.execute("DELETE FROM organizations")
    conn.commit()

    inserted = 0
    for _, row in df.iterrows():
        try:
            cursor.execute("""
                INSERT INTO organizations
                    (name, address, phone, lat, lng, languages, last_verified, is_active)
                VALUES (?, ?, ?, ?, ?, ?, ?, 1)
            """, (
                row.get("org_name"),
                row.get("address"),
                row.get("phone"),
                row.get("lat") if pd.notna(row.get("lat", None)) else None,
                row.get("lng") if pd.notna(row.get("lng", None)) else None,
                row.get("languages"),
                row.get("last_verified"),
            ))
            org_id = cursor.lastrowid

            # Insert the service
            cursor.execute("""
                INSERT INTO services
                    (org_id, category, service_name, description, hours, capacity)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                org_id,
                row.get("category"),
                row.get("org_name"),  # service name = org name for single-service orgs
                row.get("service_description"),
                row.get("hours"),
                row.get("capacity"),
            ))
            service_id = cursor.lastrowid

            # Insert eligibility as a single "other" rule from the freetext field
            eligibility_text = row.get("eligibility")
            if eligibility_text and str(eligibility_text) not in ("None", "nan", ""):
                cursor.execute("""
                    INSERT INTO eligibility (service_id, rule_type, rule_value, notes)
                    VALUES (?, 'other', ?, ?)
                """, (service_id, "see_notes", eligibility_text))

            inserted += 1
        except Exception as e:
            print(f"  ✗  Failed to insert {row.get('org_name')}: {e}")

    conn.commit()
    print(f"  ✓  Inserted {inserted} organizations")


def load_search_logs(conn: sqlite3.Connection, path: str):
    print("\n── Loading search logs ───────────────────────")
    logs = pd.read_csv(path)
    logs["matched"] = logs["matched"].map({"true": 1, "false": 0, True: 1, False: 0}).fillna(0).astype(int)
    logs["results_count"] = logs["results_count"].fillna(0).astype(int)

    cursor = conn.cursor()
    cursor.execute("DELETE FROM search_logs")
    for _, row in logs.iterrows():
        cursor.execute("""
            INSERT INTO search_logs
                (searched_at, query, category_filter, results_count, matched, session_id)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            row.get("timestamp"),
            row.get("query"),
            row.get("category_filter") if pd.notna(row.get("category_filter", None)) else None,
            int(row.get("results_count", 0)),
            int(row.get("matched", 0)),
            row.get("session_id"),
        ))
    conn.commit()
    print(f"  ✓  Loaded {len(logs)} search log entries")


# ── STEP 4: GAP ANALYSIS ─────────────────────────────────────

def gap_analysis(conn: sqlite3.Connection) -> str:
    print("\n── Gap analysis ──────────────────────────────")

    cursor = conn.cursor()

    # Unmatched searches grouped by query
    cursor.execute("""
        SELECT query, COUNT(*) AS search_count
        FROM search_logs
        WHERE matched = 0
        GROUP BY LOWER(query)
        ORDER BY search_count DESC
        LIMIT 15
    """)
    unmatched = cursor.fetchall()

    # Match rate by category
    cursor.execute("""
        SELECT
            category_filter,
            COUNT(*) AS total,
            SUM(matched) AS matched_count,
            ROUND(100.0 * SUM(matched) / COUNT(*), 1) AS match_rate
        FROM search_logs
        WHERE category_filter IS NOT NULL AND category_filter != ''
        GROUP BY category_filter
        ORDER BY match_rate ASC
    """)
    by_category = cursor.fetchall()

    # Overall stats
    cursor.execute("SELECT COUNT(*), SUM(matched) FROM search_logs")
    total, matched_total = cursor.fetchone()
    overall_rate = round(100 * matched_total / total, 1) if total else 0

    lines = []
    lines.append("=" * 56)
    lines.append("  COMMUNITY RESOURCE NAVIGATOR — GAP ANALYSIS REPORT")
    lines.append(f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    lines.append("=" * 56)

    lines.append(f"\n  Overall match rate:  {overall_rate}%  ({matched_total}/{total} searches)\n")

    lines.append("  MATCH RATE BY CATEGORY")
    lines.append("  " + "-" * 40)
    for row in by_category:
        bar_len = int((row["match_rate"] or 0) / 5)
        bar = "█" * bar_len + "░" * (20 - bar_len)
        lines.append(f"  {(row['category_filter'] or 'unknown'):<16} {bar}  {row['match_rate']}%")

    lines.append("\n  TOP UNMET NEEDS  (searches with zero matches)")
    lines.append("  " + "-" * 40)
    for row in unmatched:
        lines.append(f"  {row['search_count']:>3}x  {row['query']}")

    lines.append("\n  RECOMMENDED ACTIONS")
    lines.append("  " + "-" * 40)
    lines.append("  1. Recruit overnight shelter options for single adult men")
    lines.append("  2. Add bilingual (Spanish) mental health provider")
    lines.append("  3. Source after-hours / weekend utility assistance")
    lines.append("  4. Find pet-friendly emergency housing placement")
    lines.append("\n" + "=" * 56)

    report_text = "\n".join(lines)
    print(report_text)
    return report_text


# ── STEP 5: EXPORT CLEAN CSV ─────────────────────────────────

def export_clean(df: pd.DataFrame, path: str):
    df.drop(columns=["stale"], errors="ignore").to_csv(path, index=False)
    print(f"\n── Exported clean CSV → {path}")


# ── MAIN ─────────────────────────────────────────────────────

def main():
    print("\n╔══════════════════════════════════════════════╗")
    print("║   Community Resource Navigator — Pipeline   ║")
    print("╚══════════════════════════════════════════════╝")

    # 1. Clean
    df = clean_resources(RAW_CSV)

    # 2. Quality report
    quality_report(df)

    # 3. Database
    conn = init_database(DB_PATH, SCHEMA_PATH)
    load_organizations(conn, df)
    load_search_logs(conn, LOGS_CSV)

    # 4. Gap analysis
    report = gap_analysis(conn)

    # 5. Save outputs
    export_clean(df, CLEAN_CSV)
    with open(REPORT_PATH, "w") as f:
        f.write(report)
    print(f"  ✓  Gap report saved → {REPORT_PATH}")

    conn.close()
    print("\n✅  Pipeline complete.\n")


if __name__ == "__main__":
    main()
