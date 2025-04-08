# VoiceGPT

A Flutter application that allows users to speak in Marathi, translates to English, gets responses from Gemini AI, and then translates responses back to Marathi.

## Features

- Voice recognition for Marathi language
- Text-to-speech functionality for reading responses
- Translation between Marathi and English
- Integration with Google's Gemini AI
- Direct mode to bypass translation
- Sentiment analysis of user messages
- Copy and edit functionality for messages

## Setup Instructions

1. Clone this repository
2. Create a `.env` file in the root directory with your Gemini API key:
   ```
   GEMINI_API_KEY=your_api_key_here
   ```
3. Run `flutter pub get` to install dependencies
4. Run the app with `flutter run`

## Creating a Custom App Icon

To create a custom app icon that matches the microphone icon shown in the welcome screen:

1. Use any icon creation tool (Adobe Illustrator, Figma, etc.) to create a microphone icon
2. Make sure to create a 1024x1024 PNG image
3. Save it as `assets/icon/app_icon.png`
4. For Android adaptive icons, create a foreground layer as `assets/icon/app_icon_foreground.png`
5. Run the icon generator:
   ```
   flutter pub run flutter_launcher_icons
   ```

## Building an APK

To create an APK for distribution:

1. Ensure you have set up the app icon as described above
2. Run the following command:
   ```
   flutter build apk --release
   ```
3. Find the APK file at `build/app/outputs/flutter-apk/app-release.apk`
4. Install on your Android device and enjoy!

## Technical Details

- **Speech Recognition**: Uses the `speech_to_text` package to capture voice input
- **Text-to-Speech**: Implements `flutter_tts` for spoken responses
- **Translation**: Utilizes the `translator` package for language translation
- **AI Integration**: Connects to Gemini AI using the `google_generative_ai` package
- **State Management**: Implements the Provider pattern for state management

## Privacy & Security

This app processes voice data and sends it to external services:
- Google Cloud services for speech recognition
- Translation services
- Gemini AI for generating responses

All API keys should be kept private and not committed to public repositories.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
