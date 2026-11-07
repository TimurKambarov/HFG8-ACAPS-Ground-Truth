"""Load data/risk-radar-export.csv into Supabase (risks, risk_countries, risk_triggers).

Prerequisite: run supabase/migrations/20261106000000_init.sql once in the
Supabase SQL Editor so the tables exist.

Credentials come from environment variables SUPABASE_URL and SUPABASE_SECRET_KEY,
or from the git-ignored API.key file in the repo root (KEY=value lines).
The secret key bypasses row level security — keep it out of apps and git.

Usage:
    python scripts/load_risks_to_supabase.py            # upsert everything
    python scripts/load_risks_to_supabase.py --dry-run  # parse only, no upload

Re-running is safe: rows are upserted by primary key, and triggers removed
from the CSV are deleted for the risks being loaded.
"""

from __future__ import annotations

import argparse
import math
import os
import re
import sys
from pathlib import Path

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[1]
CSV = ROOT / "data" / "risk-radar-export.csv"
KEY_FILE = ROOT / "API.key"

COLUMNS = {
    "Risk ID": "risk_id",
    "Risk Title": "title",
    "Risk Type": "risk_type",
    "ISO": "iso",
    "Country": "country",
    "Rationale": "rationale",
    "Source": "source",
    "Intensity of hazard": "intensity_of_hazard",
    "Impact": "impact",
    "Probability": "probability",
    "Risk Level": "risk_level",
    "Risk trend": "risk_trend",
    "Status": "status",
    "What materialised?": "what_materialised",
    "Hazard materialisation": "hazard_materialisation",
    "Materialisation sources": "materialisation_sources",
    "Triggers": "triggers_raw",
    "Current vulnerability / Coping capacities": "vulnerability",
    "Current vulnerability / Coping capacities sources": "vulnerability_sources",
    "Expected exposure": "expected_exposure",
    "Expected impact": "expected_impact",
    "Expected impact sources": "expected_impact_sources",
    "Expected priority needs": "expected_priority_needs",
    "Impact materialisation description": "impact_materialisation_description",
    "Rationale update": "rationale_update",
}
INT_COLUMNS = {"intensity_of_hazard", "impact"}


def credentials() -> tuple[str, str]:
    env = {}
    if KEY_FILE.exists():
        for line in KEY_FILE.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    url = os.environ.get("SUPABASE_URL") or env.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SECRET_KEY") or env.get("SUPABASE_SECRET_KEY")
    if not url or not key:
        sys.exit("Set SUPABASE_URL and SUPABASE_SECRET_KEY (env vars or API.key).")
    return url.rstrip("/"), key


def clean(v):
    """NaN -> None, normalise Windows line breaks, strip whitespace."""
    if v is None or (isinstance(v, float) and math.isnan(v)):
        return None
    if isinstance(v, str):
        v = v.replace("\r\n", "\n").replace("\r", "\n").strip()
        return v or None
    return v


def split_list(s: str | None) -> list[str]:
    return [x.strip() for x in (s or "").split(",") if x.strip()]


_LINK = re.compile(r"\[([^\]]+)\]\([^)]*\)")


def parse_triggers(risk_id: str, raw: str | None) -> list[dict]:
    """Parse the 'Trigger ID: / Title: / Description:' blocks (mirrors app/lib/models.dart)."""
    if not raw or "Trigger ID:" not in raw:
        return []
    out = []
    for pos, chunk in enumerate(raw.split("Trigger ID:")[1:], start=1):
        trigger_id = chunk.split("\n", 1)[0].strip()
        title = re.search(r"Title:[ \t]*(.*)", chunk)
        title = title.group(1).strip().rstrip(":").strip() if title else ""
        desc = re.search(r"Description:\s*([\s\S]*?)(?:\n\s*Sources:|\n\s*Completion rate:|$)", chunk)
        desc = desc.group(1).strip().lstrip(":").strip() if desc else ""
        completion = re.search(r"Completion rate:\s*(\d+)\s*%", chunk)
        out.append({
            "trigger_id": trigger_id,
            "risk_id": risk_id,
            "position": pos,
            "title": title or trigger_id,
            "description": _LINK.sub(r"\1", desc) or None,
            "completion_rate": int(completion.group(1)) if completion else None,
            "raw": ("Trigger ID:" + chunk).strip(),
        })
    return out


def build_rows():
    df = pd.read_csv(CSV, dtype=str, keep_default_na=True)
    missing = set(COLUMNS) - set(df.columns)
    if missing:
        sys.exit(f"CSV is missing columns: {sorted(missing)}")
    df = df.rename(columns=COLUMNS)[list(COLUMNS.values())]

    risks, countries, triggers = [], [], []
    for rec in df.to_dict("records"):
        row = {k: clean(v) for k, v in rec.items()}
        if not row["risk_id"]:
            continue
        for c in INT_COLUMNS:
            row[c] = int(float(row[c])) if row[c] is not None else None
        row["expected_priority_needs"] = split_list(row["expected_priority_needs"])
        risks.append(row)

        isos, names = split_list(row["iso"]), split_list(row["country"])
        if len(isos) != len(names):
            print(f"warning: {row['risk_id']} has {len(isos)} ISO codes but {len(names)} countries")
        for iso, name in zip(isos, names):
            countries.append({"risk_id": row["risk_id"], "iso": iso, "country": name})

        triggers.extend(parse_triggers(row["risk_id"], row["triggers_raw"]))
    return risks, countries, triggers


class Rest:
    def __init__(self, url: str, key: str):
        self.base = f"{url}/rest/v1"
        self.s = requests.Session()
        self.s.headers.update({"apikey": key, "Authorization": f"Bearer {key}",
                               "Content-Type": "application/json"})

    def upsert(self, table: str, rows: list[dict], on_conflict: str, chunk: int = 50):
        for i in range(0, len(rows), chunk):
            r = self.s.post(f"{self.base}/{table}", params={"on_conflict": on_conflict},
                            headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
                            json=rows[i:i + chunk], timeout=60)
            self._check(r, table)

    def delete(self, table: str, params: dict):
        self._check(self.s.delete(f"{self.base}/{table}", params=params, timeout=60), table)

    def count(self, table: str) -> int:
        r = self.s.get(f"{self.base}/{table}", params={"select": "*", "limit": 1},
                       headers={"Prefer": "count=exact"}, timeout=30)
        self._check(r, table)
        return int(r.headers["Content-Range"].split("/")[-1])

    @staticmethod
    def _check(r: requests.Response, table: str):
        if r.ok:
            return
        msg = r.text[:500]
        if r.status_code == 404 or "PGRST205" in msg or "does not exist" in msg:
            sys.exit(f"Table '{table}' not found. Run supabase/migrations/20261106000000_init.sql "
                     f"in the Supabase SQL Editor first.\n{msg}")
        sys.exit(f"{table}: HTTP {r.status_code}\n{msg}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="parse the CSV but do not upload")
    args = ap.parse_args()

    risks, countries, triggers = build_rows()
    print(f"parsed {len(risks)} risks, {len(countries)} risk-country links, {len(triggers)} triggers")
    if args.dry_run:
        return

    db = Rest(*credentials())
    db.upsert("risks", risks, "risk_id")
    ids = ",".join(f'"{r["risk_id"]}"' for r in risks)
    # Replace child rows so edits/removals in the CSV are reflected.
    db.delete("risk_countries", {"risk_id": f"in.({ids})"})
    db.upsert("risk_countries", countries, "risk_id,iso")
    db.delete("risk_triggers", {"risk_id": f"in.({ids})"})
    db.upsert("risk_triggers", triggers, "trigger_id")

    for t in ("risks", "risk_countries", "risk_triggers"):
        print(f"{t}: {db.count(t)} rows in Supabase")


if __name__ == "__main__":
    main()
