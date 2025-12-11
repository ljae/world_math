import requests
import json

API_KEY = "099f43663ee448dcbf60a12eac4d54ca"
URL = "https://open.neis.go.kr/hub/schoolInfo"
SCHOOL_KINDS = ["초등학교", "중학교", "고등학교"]

all_schools = []

for kind in SCHOOL_KINDS:
    page = 1
    while True:
        params = {
            "KEY": API_KEY,
            "Type": "json",
            "pIndex": page,
            "pSize": 1000,
            "SCHUL_KND_SC_NM": kind
        }
        
        print(f"Fetching page {page} for {kind}...")
        
        response = requests.get(URL, params=params)
        
        if response.status_code != 200:
            print(f"Request failed with status code: {response.status_code}")
            break
            
        try:
            data = response.json()
        except json.JSONDecodeError:
            print("Failed to decode JSON from response")
            break

        if "schoolInfo" not in data:
            # This indicates the end of data for the current school kind
            break
            
        school_info = data.get("schoolInfo")
        if not school_info or len(school_info) < 2 or "row" not in school_info[1]:
            # No more rows, break the loop
            break

        schools = school_info[1]["row"]
        
        for school in schools:
            all_schools.append({
                "school_name": school["SCHUL_NM"],
                "location": school["LCTN_SC_NM"]
            })
        
        # Check if this is the last page
        list_total_count = school_info[0]["head"][0]["list_total_count"]
        if page * 1000 >= list_total_count:
            break
            
        page += 1

with open("schools.json", "w", encoding="utf-8") as f:
    json.dump(all_schools, f, ensure_ascii=False, indent=2)

print(f"Successfully fetched and saved {len(all_schools)} schools to schools.json")