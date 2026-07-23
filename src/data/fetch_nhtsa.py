"""Pull NHTSA recalls + complaints for EV models, filtered to battery/electrical component tags.

Usage: python src/data/fetch_nhtsa.py
Writes raw API responses and a filtered CSV to data/raw/nhtsa/.
"""
import csv
import json
import time
from pathlib import Path

import requests

RECALLS_URL = "https://api.nhtsa.gov/recalls/recallsByVehicle"
COMPLAINTS_URL = "https://api.nhtsa.gov/complaints/complaintsByVehicle"

OUT_DIR = Path(__file__).resolve().parents[2] / "data" / "raw" / "nhtsa"

# Component tags that indicate battery/electrical relevance (per Capstone_Project_Plan.md Section 2).
BATTERY_ELECTRICAL_TAGS = ("TRACTION BATTERY", "ELECTRICAL SYSTEM")

# ~18 EV models x several model years, per the plan's "15-20 EV models" target.
EV_MODELS = {
    "chevrolet": ["bolt ev", "bolt euv", "equinox ev", "blazer ev"],
    "tesla": ["model 3", "model y", "model s", "model x"],
    "nissan": ["leaf"],
    "ford": ["mustang mach-e", "f-150 lightning"],
    "volkswagen": ["id.4"],
    "hyundai": ["ioniq 5", "ioniq 6", "kona electric"],
    "kia": ["ev6", "niro ev"],
    "rivian": ["r1t", "r1s"],
    "audi": ["e-tron"],
    "bmw": ["i4"],
    "polestar": ["polestar 2"],
    "toyota": ["bz4x"],
    "honda": ["prologue"],
}
MODEL_YEARS = list(range(2019, 2025))


def is_battery_electrical(component: str) -> bool:
    component = (component or "").upper()
    return any(tag in component for tag in BATTERY_ELECTRICAL_TAGS)


def fetch_json(url: str, params: dict) -> dict:
    resp = requests.get(url, params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    raw_recalls = []
    raw_complaints = []

    combos = [
        (make, model, year)
        for make, models in EV_MODELS.items()
        for model in models
        for year in MODEL_YEARS
    ]
    print(f"Querying {len(combos)} make/model/year combinations...")

    for make, model, year in combos:
        params = {"make": make, "model": model, "modelYear": year}
        try:
            recalls = fetch_json(RECALLS_URL, params)
            for r in recalls.get("results", []):
                r["_make"], r["_model"], r["_modelYear"] = make, model, year
                raw_recalls.append(r)
        except requests.RequestException as e:
            print(f"  recalls failed for {make} {model} {year}: {e}")

        try:
            complaints = fetch_json(COMPLAINTS_URL, params)
            for c in complaints.get("results", []):
                c["_make"], c["_model"], c["_modelYear"] = make, model, year
                raw_complaints.append(c)
        except requests.RequestException as e:
            print(f"  complaints failed for {make} {model} {year}: {e}")

        time.sleep(0.1)  # be polite to the public API

    (OUT_DIR / "recalls_raw.json").write_text(json.dumps(raw_recalls, indent=2))
    (OUT_DIR / "complaints_raw.json").write_text(json.dumps(raw_complaints, indent=2))
    print(f"Raw: {len(raw_recalls)} recalls, {len(raw_complaints)} complaints")

    filtered_recalls = [r for r in raw_recalls if is_battery_electrical(r.get("Component"))]
    filtered_complaints = [c for c in raw_complaints if is_battery_electrical(c.get("components"))]
    print(
        f"Filtered to battery/electrical: {len(filtered_recalls)} recalls, "
        f"{len(filtered_complaints)} complaints"
    )

    write_csv(OUT_DIR / "recalls_battery_electrical.csv", filtered_recalls)
    write_csv(OUT_DIR / "complaints_battery_electrical.csv", filtered_complaints)


def write_csv(path: Path, rows: list[dict]):
    if not rows:
        path.write_text("")
        return
    fieldnames = sorted({key for row in rows for key in row})
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
