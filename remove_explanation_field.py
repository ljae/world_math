import firebase_admin
from firebase_admin import credentials, firestore
import sys
import os

# Configuration
FIREBASE_PROJECT_ID = "real-math-d9ddf"
SERVICE_ACCOUNT_KEY_PATH = os.path.expanduser("firebase-credentials.json")

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        # Check if already initialized
        firebase_admin.get_app()
        print("✓ Firebase already initialized")
        return firestore.client()
    except ValueError:
        # Not initialized yet. Let's try to initialize.
        pass

    # Try to use GOOGLE_APPLICATION_CREDENTIALS environment variable first
    cred_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
    if cred_path and os.path.exists(cred_path):
        print("✓ Found credentials via GOOGLE_APPLICATION_CREDENTIALS.")
        try:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred, {'projectId': FIREBASE_PROJECT_ID})
            print(f"✓ Firebase initialized for project: {FIREBASE_PROJECT_ID}")
            return firestore.client()
        except Exception as e:
            print(f"✗ Error initializing Firebase with GOOGLE_APPLICATION_CREDENTIALS: {e}")
            # Fall through to try the default path

    # If env var fails or is not set, try the hardcoded path
    if os.path.exists(SERVICE_ACCOUNT_KEY_PATH):
        print("✓ Found credentials at the default path.")
        try:
            cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
            firebase_admin.initialize_app(cred, {'projectId': FIREBASE_PROJECT_ID})
            print(f"✓ Firebase initialized for project: {FIREBASE_PROJECT_ID}")
            return firestore.client()
        except Exception as e:
            print(f"✗ Error initializing Firebase with default path: {e}")

    # If we are here, we couldn't initialize Firebase
    print("✗ Error: Could not find Firebase credentials.")
    print("Please set the GOOGLE_APPLICATION_CREDENTIALS environment variable or")
    print(f"place your service account key at: {SERVICE_ACCOUNT_KEY_PATH}")
    sys.exit(1)


def remove_explanation_field(db):
    """Removes the 'explanation' field from all documents in the 'problems' collection."""
    problems_ref = db.collection('problems')
    docs = problems_ref.stream()

    batch = db.batch()
    doc_count = 0
    processed_docs = 0

    for doc in docs:
        if 'explanation' in doc.to_dict():
            print(f"  - Scheduling deletion for doc id: {doc.id}")
            batch.update(doc.reference, {'explanation': firestore.DELETE_FIELD})
            doc_count += 1
        
        processed_docs +=1

        # Firestore allows up to 500 operations in a single batch.
        # Commit the batch every 499 documents to be safe.
        if doc_count == 499:
            print("Committing a batch of 499 updates...")
            batch.commit()
            # reset batch and doc_count
            batch = db.batch()
            doc_count = 0
    
    # Commit the remaining batch
    if doc_count > 0:
        print(f"Committing the final batch of {doc_count} updates...")
        batch.commit()
        print(f"✓ Successfully removed 'explanation' field from {doc_count} documents.")
    elif processed_docs > 0:
        print(f"✓ All {processed_docs} documents processed. No 'explanation' fields needed to be removed.")
    else:
        print("No documents found in the 'problems' collection.")


def main():
    print("=== Remove 'explanation' field from 'problems' collection ===")
    db = initialize_firebase()
    remove_explanation_field(db)
    print("==========================================================")

if __name__ == '__main__':
    main()