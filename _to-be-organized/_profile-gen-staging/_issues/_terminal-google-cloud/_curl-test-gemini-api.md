
google workplace
gig.graham@dailyfood.io

google ai studio
https://aistudio.google.com/api-keys

GEMINI_API_KEY=AIzaSyCh3bV6tJvICQck3Ihiw5vXZ2JAm3JCfNc

name
extend-intel-google-gemini

project name
projects/257369973145

project number
257369973145

curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H 'Content-Type: application/json' \
  -H 'X-goog-api-key: AIzaSyCh3bV6tJvICQck3Ihiw5vXZ2JAm3JCfNc' \
  -X POST \
  -d '{
    "contents": [
      {
        "parts": [
          {
            "text": "Explain how AI works in a few words"
          }
        ]
      }
    ]
  }'
