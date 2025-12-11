import json
import firebase_admin
from firebase_admin import credentials, firestore

# Configuration
FIREBASE_PROJECT_ID = "real-math-d9ddf"
SCHOOLS_FILE = "schools.json"

# List of prefixes to remove for the 'school_name_only' field
PREFIXES = [
    '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종', 
    '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주'
]

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        firebase_admin.get_app()
        print("✓ Firebase already initialized")
    except ValueError:
        try:
            cred = credentials.Certificate("firebase-credentials.json")
            firebase_admin.initialize_app(cred, {
                'projectId': FIREBASE_PROJECT_ID,
            })
            print(f"✓ Firebase initialized for project: {FIREBASE_PROJECT_ID}")
        except FileNotFoundError:
            print("✗ Error: firebase-credentials.json not found.")
            print("Please make sure the service account key file is in the same directory.")
            return None
        except Exception as e:
            print(f"✗ Failed to initialize Firebase: {e}")
            return None
            
    return firestore.client()

def upload_schools(db):
    """Uploads schools from the JSON file to Firestore with a dedicated search field."""
    try:
        with open(SCHOOLS_FILE, 'r', encoding='utf-8') as f:
            schools = json.load(f)
    except FileNotFoundError:
        print(f"✗ Error: {SCHOOLS_FILE} not found. Please run get_schools.py first.")
        return

    batch = db.batch()
    schools_collection = db.collection('schools')
    
    # First, delete all existing documents in the 'schools' collection
    print("Deleting all existing schools...")
    docs = schools_collection.stream()
    deleted = 0
    for doc in docs:
        doc.reference.delete()
        deleted += 1
    print(f"✓ Deleted {deleted} existing schools.")


    print("Uploading new school data with 'school_name_only' field...")
    count = 0
    for school in schools:
        school_name = school['school_name']
        school_name_only = school_name
        
        for prefix in PREFIXES:
            if school_name.startswith(prefix):
                school_name_only = school_name[len(prefix):]
                break # Stop after finding the first matching prefix
        
        school_data = {
            'school_name': school_name,
            'school_name_only': school_name_only,
            'location': school['location'],
        }

        doc_ref = schools_collection.document() # Let firestore create a new ID
        batch.set(doc_ref, school_data)
        count += 1
        if count % 500 == 0: # Commit every 500 documents
            print(f"Committing batch of 500 schools... ({count}/{len(schools)})")
            batch.commit()
            batch = db.batch()

    # Commit the remaining documents
    if count % 500 != 0:
        print(f"Committing final batch of {count % 500} schools...")
        batch.commit()

    print(f"\n✓ Successfully uploaded {len(schools)} schools to the 'schools' collection.")

def main():
    print("\n=== Firebase School Uploader (with school_name_only) ===\n")
    db = initialize_firebase()
    if db:
        upload_schools(db)

if __name__ == '__main__':
    main()
