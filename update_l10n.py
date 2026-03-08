import os
import json

l10n_dir = r"c:\Users\TheIM\Desktop\RATEMYPOLITICIAN\rate_my_mantri\assets\l10n"

new_keys = {
    "about_app_disclaimer": "About & Disclaimer",
    "data_sources_and_disclaimer": "Data sources and non-affiliation",
    "disclaimer_title": "Disclaimer (Non-Affiliation)",
    "disclaimer_text": "Rate My Mantri is an independent, non-governmental platform. We are not affiliated with, endorsed by, or representative of any government entity.",
    "data_sources_title": "Data Sources",
    "data_sources_text": "Information provided in this app is aggregated from publicly available sources such as the Election Commission of India (eci.gov.in), MyNeta (myneta.info), and open government data portals."
}

for filename in os.listdir(l10n_dir):
    if filename.endswith(".json"):
        filepath = os.path.join(l10n_dir, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        changed = False
        for k, v in new_keys.items():
            if k not in data:
                data[k] = v
                changed = True
                
        if changed:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"Updated {filename}")

print("Done")
