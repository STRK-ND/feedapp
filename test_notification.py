#!/usr/bin/env python3
"""
Simple script to send test FCM notifications
Requires: pip install requests

To use:
1. Go to Firebase Console → Project Settings → Cloud Messaging
2. Copy the "Server key" (legacy) or create an OAuth token
3. Run: python test_notification.py

Note: The legacy FCM API requires a server key. For the newer HTTP v1 API,
you need a service account token which is more complex.
"""

import requests
import json

# Firebase project info
FCM_URL = "https://fcm.googleapis.com/fcm/send"
FCM_SERVER_KEY = "YOUR_FCM_SERVER_KEY_HERE"  # Get from Firebase Console → Settings → Cloud Messaging

# Device token - you need to get this from your app
# The app prints it to console when starting. Look for:
# "[Notification] FCM Token: ..."
DEVICE_TOKEN = "YOUR_DEVICE_TOKEN_HERE"

def send_notification(title, body, token):
    """Send a test notification to device"""

    headers = {
        'Authorization': f'key={FCM_SERVER_KEY}',
        'Content-Type': 'application/json',
    }

    payload = {
        'to': token,
        'notification': {
            'title': title,
            'body': body,
        },
        'data': {
            'type': 'test',
            'timestamp': str(datetime.now()),
        },
    }

    response = requests.post(FCM_URL, headers=headers, json=payload)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")
    return response.json()

def send_to_topic(title, body, topic="all"):
    """Send notification to a topic (no need for device token)"""

    headers = {
        'Authorization': f'key={FCM_SERVER_KEY}',
        'Content-Type': 'application/json',
    }

    payload = {
        'to': f'/topics/{topic}',
        'notification': {
            'title': title,
            'body': body,
        },
    }

    response = requests.post(FCM_URL, headers=headers, json=payload)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")
    return response.json()

if __name__ == "__main__":
    import sys
    from datetime import datetime

    print("=" * 50)
    print("Firebase Cloud Messaging Test Script")
    print("=" * 50)
    print()
    print("To use this script:")
    print("1. Get your FCM Server Key from Firebase Console:")
    print("   Project Settings → Cloud Messaging → Server key")
    print()
    print("2. Get your device FCM token from the app console output")
    print("   Look for: '[Notification] FCM Token: ...'")
    print()
    print("3. Update DEVICE_TOKEN and FCM_SERVER_KEY in this script")
    print()
    print("Then run: python test_notification.py")
