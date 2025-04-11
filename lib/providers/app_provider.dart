import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Message class to store conversation entries
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isDirectMode;
  final bool isError;
  final DateTime timestamp;
  final bool isEdited;
  final String? sentiment; // Add sentiment field

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isDirectMode =
        false,
    this.isError =
        false,
    DateTime? timestamp,
    this.isEdited =
        false,
    this.sentiment,
  }) : timestamp =
           timestamp ??
           DateTime.now();
}

class AppProvider
    extends
        ChangeNotifier {
  final SpeechToText _speechToText =
      SpeechToText();
  final FlutterTts _flutterTts =
      FlutterTts();
  final GoogleTranslator _translator =
      GoogleTranslator();

  bool _isListening =
      false;
  bool _isProcessing =
      false;
  bool _isReplying =
      false;
  bool _isConnected =
      true;
  bool _bypassTranslation =
      false;

  String _speechText =
      '';
  String _translatedText =
      '';
  String _geminiResponse =
      '';
  String _translatedResponse =
      '';
  String _logs =
      ''; // To store logs

  // Chat history
  final List<
    ChatMessage
  >
  _messages =
      [];

  // Class variables at the top
  bool _isAnalyzingSentiment =
      false;

  // Getters
  bool get isListening =>
      _isListening;
  bool get isProcessing =>
      _isProcessing;
  bool get isReplying =>
      _isReplying;
  bool get isConnected =>
      _isConnected;
  bool get bypassTranslation =>
      _bypassTranslation;

  String get speechText =>
      _speechText;
  String get translatedText =>
      _translatedText;
  String get geminiResponse =>
      _geminiResponse;
  String get translatedResponse =>
      _translatedResponse;
  String get logs =>
      _logs;
  List<
    ChatMessage
  >
  get messages =>
      _messages;

  AppProvider() {
    _addLog(
      'AppProvider initialized',
    );
    _initSpeech();
    _initTts();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  // Add to log
  void _addLog(
    String message,
  ) {
    debugPrint(
      'VoiceGPT: $message',
    );
    _logs =
        '$message\n$_logs';
    notifyListeners();
  }

  // Initialize speech recognition
  Future<
    void
  >
  _initSpeech() async {
    _addLog(
      'Initializing speech recognition...',
    );
    bool available = await _speechToText.initialize(
      onError: (
        error,
      ) {
        _addLog(
          'Speech recognition error: $error',
        );

        // Handle specific error types
        if (error.errorMsg ==
            'error_no_match') {
          _speechText =
              '(Speech not recognized. Please try speaking more clearly or check if Marathi is enabled on your device.)';
          _isListening =
              false;
          notifyListeners();
        }
      },
      onStatus:
          (
            status,
          ) => _addLog(
            'Speech status: $status',
          ),
      debugLogging:
          true, // Enable detailed logging
    );

    if (available) {
      _addLog(
        'Speech recognition initialized successfully',
      );
      // Get available locales
      final locales =
          await _speechToText.locales();
      _addLog(
        'Available locales: ${locales.map((e) => "${e.localeId} (${e.name})").join(', ')}',
      );

      // Check if Marathi is available
      final marathiLocales =
          locales
              .where(
                (
                  locale,
                ) =>
                    locale.localeId.contains(
                      'mr',
                    ) ||
                    locale.name.toLowerCase().contains(
                      'marathi',
                    ) ||
                    locale.localeId.contains(
                      'in',
                    ) || // Also check for Indian locales as fallback
                    locale.name.toLowerCase().contains(
                      'india',
                    ),
              )
              .toList();

      if (marathiLocales.isNotEmpty) {
        _addLog(
          'Found potential Marathi/Indian locales: ${marathiLocales.map((e) => "${e.localeId} (${e.name})").join(', ')}',
        );
      } else {
        _addLog(
          'Warning: No Marathi or Indian locales found. Speech recognition may not work properly.',
        );
      }
    } else {
      _addLog(
        'Speech recognition failed to initialize',
      );
    }
  }

  // Initialize text-to-speech
  Future<
    void
  >
  _initTts() async {
    _addLog(
      'Initializing text-to-speech...',
    );

    _flutterTts.setErrorHandler(
      (
        error,
      ) {
        _addLog(
          'TTS error: $error',
        );
      },
    );

    _flutterTts.setStartHandler(
      () {
        _addLog(
          'TTS started speaking',
        );
      },
    );

    _flutterTts.setCompletionHandler(
      () {
        _addLog(
          'TTS finished speaking',
        );
        _isReplying =
            false;
        notifyListeners();
      },
    );

    // Get available languages
    final languages =
        await _flutterTts.getLanguages;
    _addLog(
      'Available TTS languages: ${languages.toString()}',
    );

    // Check if Marathi is available
    final hasMarathi =
        languages.toString().toLowerCase().contains(
          'marathi',
        ) ||
        languages.toString().contains(
          'mr',
        );
    _addLog(
      'Marathi TTS ${hasMarathi ? 'is' : 'is not'} available',
    );

    if (hasMarathi) {
      await _flutterTts.setLanguage(
        'mr-IN',
      ); // Marathi language
    } else {
      // Fallback to Hindi or English
      if (languages.toString().toLowerCase().contains(
            'hindi',
          ) ||
          languages.toString().contains(
            'hi',
          )) {
        await _flutterTts.setLanguage(
          'hi-IN',
        ); // Hindi language
        _addLog(
          'Fallback to Hindi TTS',
        );
      } else {
        await _flutterTts.setLanguage(
          'en-IN',
        ); // Indian English
        _addLog(
          'Fallback to Indian English TTS',
        );
      }
    }

    await _flutterTts.setSpeechRate(
      0.5,
    );
    await _flutterTts.setVolume(
      1.0,
    );
    await _flutterTts.setPitch(
      1.0,
    );
    _addLog(
      'TTS initialized successfully',
    );
  }

  // Check internet connectivity
  Future<
    void
  >
  _checkConnectivity() async {
    _addLog(
      'Checking internet connectivity...',
    );
    var connectivityResult =
        await Connectivity().checkConnectivity();
    _isConnected =
        connectivityResult !=
        ConnectivityResult.none;
    _addLog(
      'Internet connection: ${_isConnected ? 'Connected' : 'Disconnected'}',
    );
    notifyListeners();
  }

  // Setup connectivity listener
  void _setupConnectivityListener() {
    _addLog(
      'Setting up connectivity listener...',
    );
    Connectivity().onConnectivityChanged.listen(
      (
        result,
      ) {
        _isConnected =
            result !=
            ConnectivityResult.none;
        _addLog(
          'Connectivity changed: ${_isConnected ? 'Connected' : 'Disconnected'}',
        );
        notifyListeners();
      },
    );
  }

  // Start listening
  Future<
    void
  >
  startListening() async {
    _addLog(
      'Starting speech recognition...',
    );
    if (!_isConnected) {
      _addLog(
        'Cannot start listening: No internet connection',
      );
      return;
    }

    _isListening =
        true;
    _speechText =
        '';
    notifyListeners();

    try {
      // Try a simpler approach - use the default locale but with specific options
      await _speechToText.listen(
        onResult: (
          result,
        ) {
          if (result.recognizedWords.isNotEmpty) {
            _speechText =
                result.recognizedWords;
            _addLog(
              'Recognized words: $_speechText',
            );
          } else {
            _addLog(
              'No words recognized in this result',
            );
          }
          notifyListeners();
        },
        onSoundLevelChange: (
          level,
        ) {
          // Auto-stop after 3 seconds of deep silence (level very close to zero)
          if (level <
              0.005) {
            _silenceTimer ??= Future.delayed(
              const Duration(
                milliseconds:
                    3000,
              ),
              () {
                if (_isListening &&
                    _speechText.isNotEmpty) {
                  _addLog(
                    'Auto-stopping due to silence',
                  );
                  stopListening();
                }
                _silenceTimer =
                    null;
              },
            );
          } else {
            // Cancel silence timer if sound is detected again
            _silenceTimer =
                null;
          }
        },
        cancelOnError:
            false,
        partialResults:
            true,
        listenFor: const Duration(
          seconds:
              60,
        ),
        pauseFor: const Duration(
          seconds:
              5,
        ),
      );

      _addLog(
        'Listening started successfully with default locale',
      );
    } catch (
      e
    ) {
      _addLog(
        'Error starting listening: $e',
      );
      _isListening =
          false;
      _speechText =
          'Error starting speech recognition. Please try again.';
      notifyListeners();
    }
  }

  // Variable to track silence detection timer
  Future? _silenceTimer;

  // Stop listening
  Future<
    void
  >
  stopListening() async {
    _addLog(
      'Stopping speech recognition...',
    );
    try {
      await _speechToText.stop();
      _isListening =
          false;
      _addLog(
        'Listening stopped',
      );

      if (_speechText.isNotEmpty) {
        _addLog(
          'Processing voice input: "$_speechText"',
        );
        processVoiceInput();
      } else {
        _addLog(
          'No speech detected',
        );
      }
    } catch (
      e
    ) {
      _addLog(
        'Error stopping speech recognition: $e',
      );
    }

    notifyListeners();
  }

  // Process voice input
  Future<
    void
  >
  processVoiceInput() async {
    if (!_isConnected) {
      _addLog(
        'Cannot process: No internet connection',
      );
      return;
    }

    if (_speechText.isEmpty) {
      _addLog(
        'Cannot process: Empty speech text',
      );
      return;
    }

    _isProcessing =
        true;
    notifyListeners();

    try {
      _addLog(
        'Starting processing workflow...',
      );

      // Add user message to the conversation
      _addMessage(
        _speechText,
        true,
        _bypassTranslation,
        false,
      );

      if (_bypassTranslation) {
        // Direct mode: Skip translation and send directly to Gemini
        _addLog(
          'Using direct mode (bypassing translation)',
        );
        _translatedText =
            _speechText; // Use original text

        // Get response from Gemini
        _addLog(
          'Sending untranslated text directly to Gemini',
        );
        await getGeminiResponse();

        // No translation back needed
        _translatedResponse =
            _geminiResponse;
        _addLog(
          'Response received directly from Gemini',
        );

        // Add AI response to the conversation
        _addMessage(
          _translatedResponse,
          false,
          _bypassTranslation,
          false,
        );

        // Speak response
        _addLog(
          'Speaking response',
        );
        speakResponse();
      } else {
        // Standard mode with translation
        _addLog(
          'Using standard mode with translation',
        );

        // 1. Translate Marathi to English
        _addLog(
          'Step 1: Translating from Marathi to English',
        );
        await translateToEnglish(
          _speechText,
        );

        // 2. Get response from Gemini
        _addLog(
          'Step 2: Getting response from Gemini',
        );
        await getGeminiResponse();

        // 3. Translate English response to Marathi
        _addLog(
          'Step 3: Translating response from English to Marathi',
        );
        await translateToMarathi(
          _geminiResponse,
        );

        // 4. Add AI response to the conversation
        _addMessage(
          _translatedResponse,
          false,
          _bypassTranslation,
          false,
        );

        // 5. Speak response
        _addLog(
          'Step 4: Speaking response',
        );
        speakResponse();
      }

      _addLog(
        'Processing completed successfully',
      );
    } catch (
      e
    ) {
      _addLog(
        'Error during processing workflow: $e',
      );
      _addMessage(
        '(Error processing your request: ${e.toString()})',
        false,
        _bypassTranslation,
        true,
      );
    } finally {
      _isProcessing =
          false;
      notifyListeners();
    }
  }

  // Translate from Marathi to English
  Future<
    void
  >
  translateToEnglish(
    String text,
  ) async {
    _addLog(
      'Translating from Marathi to English: "$text"',
    );
    try {
      final translation = await _translator.translate(
        text,
        from:
            'mr', // Marathi
        to:
            'en', // English
      );

      _translatedText =
          translation.text;
      _addLog(
        'Translation result: "$_translatedText"',
      );
      notifyListeners();
    } catch (
      e
    ) {
      _addLog(
        'Translation error: $e',
      );
      _translatedText =
          text; // Fallback to original text
      _addLog(
        'Using original text as fallback',
      );
      notifyListeners();
    }
  }

  // Helper method to ensure response has markdown formatting
  String _ensureMarkdownFormatting(
    String text,
  ) {
    if (!text.contains(
          '**',
        ) &&
        !text.contains(
          '*',
        ) &&
        !text.contains(
          '- ',
        ) &&
        !text.contains(
          '`',
        )) {
      // No markdown detected, add some basic formatting

      // Find important terms to bold (proper nouns, etc.)
      final sentences = text.split(
        '. ',
      );
      for (
        int i = 0;
        i <
            sentences.length;
        i++
      ) {
        // Try to identify important terms (words with first letter capitalized)
        final words = sentences[i].split(
          ' ',
        );
        for (
          int j = 0;
          j <
              words.length;
          j++
        ) {
          final word =
              words[j];
          if (word.length >
                  1 &&
              word[0] ==
                  word[0].toUpperCase() &&
              word[1] ==
                  word[1].toLowerCase() &&
              ![
                'I',
                'A',
                '.',
                ',',
                '?',
                '!',
              ].contains(
                word,
              ) &&
              j >
                  0) {
            // Skip first word of sentence
            words[j] =
                '**$word**';
          }
        }
        sentences[i] = words.join(
          ' ',
        );
      }

      // Add bullet points for sequences of short sentences
      String result = sentences.join(
        '. ',
      );

      // Replace numbered lists with bullet points
      result = result.replaceAllMapped(
        RegExp(
          r'(\d+\.\s)(.+?)(?=\s\d+\.\s|$)',
        ),
        (
          match,
        ) =>
            '\n- ${match.group(2)}',
      );

      return result;
    }
    return text;
  }

  // Get response from Gemini
  Future<
    void
  >
  getGeminiResponse() async {
    _addLog(
      'Sending request to Gemini: "$_translatedText"',
    );
    try {
      final apiKey =
          dotenv.env['GEMINI_API_KEY'] ??
          '';
      if (apiKey.isEmpty) {
        _addLog(
          'Error: Gemini API key is missing',
        );
        _geminiResponse =
            'Error: API key is missing. Please add your Gemini API key to the .env file.';
        notifyListeners();
        return;
      }

      _addLog(
        'Initializing Gemini model...',
      );

      // List of models to try in order
      final modelOptions = [
        'gemini-1.5-flash',
        'gemini-1.5-pro',
        'gemini-pro',
        'gemini-1.0-pro',
      ];
      String? lastErrorMessage;

      // Try each model in sequence until one works
      for (final modelName in modelOptions) {
        try {
          _addLog(
            'Trying model: $modelName',
          );
          final model = GenerativeModel(
            model:
                modelName,
            apiKey:
                apiKey,
          );

          // Create enhanced prompt that requests markdown formatting
          final enhancedText = """
$_translatedText

IMPORTANT: Your response will be read aloud using text-to-speech synthesis. Please optimize your answer for spoken audio:
1. Use simple, conversational language that flows naturally when spoken
2. Keep sentences short and easy to understand
3. Avoid complex symbols that don't sound natural when read aloud
4. Use normal punctuation to create natural pauses
5. Spell out abbreviations or numbers when appropriate
6. Avoid lengthy lists or tables that would be difficult to follow when spoken

Also format with markdown:
1. Use **double asterisks** for important terms
2. Use *single asterisks* for emphasis
3. Use - or * at the start of lines for bullet points
4. Use `backticks` for code or technical terms
5. Use ## for headings

Your response MUST be optimized for both spoken delivery and text readability.
""";

          _addLog(
            'Sending content to model: $modelName',
          );
          final content = [
            Content.text(
              enhancedText,
            ),
          ];
          final response = await model.generateContent(
            content,
          );

          _geminiResponse =
              response.text ??
              'No response from Gemini';
          // Apply post-processing to ensure markdown formatting
          _geminiResponse = _ensureMarkdownFormatting(
            _geminiResponse,
          );
          _addLog(
            'Gemini response received from $modelName: "$_geminiResponse"',
          );
          notifyListeners();
          return; // Success, exit the method
        } catch (
          e
        ) {
          lastErrorMessage = _formatErrorMessage(
            e,
          );
          _addLog(
            'Error with model $modelName: $lastErrorMessage',
          );
          // Continue to next model
        }
      }

      // If we got here, all models failed
      throw Exception(
        'All Gemini models failed. Last error: $lastErrorMessage',
      );
    } catch (
      e
    ) {
      final errorMessage = _formatErrorMessage(
        e,
      );
      _addLog(
        'Gemini error: $errorMessage',
      );

      // Determine user-friendly error message
      if (errorMessage.contains(
        'API key',
      )) {
        _geminiResponse =
            'Error: Invalid API key. Please check your Gemini API key.';
      } else if (errorMessage.contains(
        'quota',
      )) {
        _geminiResponse =
            'Error: API quota exceeded. Please try again later.';
      } else if (errorMessage.contains(
            'not found',
          ) ||
          errorMessage.contains(
            'not supported',
          )) {
        _geminiResponse =
            'Error: The Gemini model is not available. Please check for service updates.';
      } else {
        _geminiResponse =
            'Error communicating with Gemini. Please check your internet connection.';
      }

      notifyListeners();
    }
  }

  // Helper method to extract meaningful error message
  String _formatErrorMessage(
    dynamic error,
  ) {
    final message =
        error.toString();
    // Extract the most useful part of the error message
    if (message.contains(
      'ApiException:',
    )) {
      return message
          .split(
            'ApiException:',
          )
          .last
          .trim();
    }
    return message;
  }

  // Translate from English to Marathi
  Future<
    void
  >
  translateToMarathi(
    String text,
  ) async {
    _addLog(
      'Translating from English to Marathi: "$text"',
    );
    try {
      final translation = await _translator.translate(
        text,
        from:
            'en', // English
        to:
            'mr', // Marathi
      );

      _translatedResponse =
          translation.text;
      _addLog(
        'Translation result: "$_translatedResponse"',
      );
      notifyListeners();
    } catch (
      e
    ) {
      _addLog(
        'Translation error: $e',
      );
      _translatedResponse =
          text; // Fallback to original text
      _addLog(
        'Using original text as fallback',
      );
      notifyListeners();
    }
  }

  // Clean text for TTS by removing special characters and improving speech synthesis
  String _cleanTextForTTS(
    String text,
  ) {
    // Remove markdown formatting for better speech
    String cleanedText = text
        .replaceAll(
          '**',
          '',
        )
        .replaceAll(
          '*',
          '',
        )
        .replaceAll(
          '`',
          '',
        )
        .replaceAll(
          '##',
          '',
        )
        .replaceAll(
          '#',
          '',
        )
        .replaceAll(
          '>',
          '',
        )
        .replaceAll(
          '_',
          ' ',
        )
        .replaceAll(
          '=',
          ' equals ',
        )
        .replaceAll(
          '+',
          ' plus ',
        )
        .replaceAll(
          '|',
          '',
        )
        .replaceAll(
          '\\',
          '',
        )
        .replaceAll(
          '/',
          '',
        )
        .replaceAll(
          '[',
          '',
        )
        .replaceAll(
          ']',
          '',
        )
        .replaceAll(
          '{',
          '',
        )
        .replaceAll(
          '}',
          '',
        )
        .replaceAll(
          '(',
          '',
        )
        .replaceAll(
          ')',
          '',
        );

    // Add natural pauses with punctuation (no SSML tags)
    cleanedText = cleanedText.replaceAll(
      '. ',
      '. ... ',
    );
    cleanedText = cleanedText.replaceAll(
      '? ',
      '? ... ',
    );
    cleanedText = cleanedText.replaceAll(
      '! ',
      '! ... ',
    );

    // Add slight pauses for commas
    cleanedText = cleanedText.replaceAll(
      ', ',
      ', .. ',
    );

    // Replace bullet points with pauses and better spoken indicators
    cleanedText = cleanedText.replaceAll(
      '- ',
      '... • ',
    );

    // Replace multiple consecutive spaces and line breaks
    cleanedText =
        cleanedText
            .replaceAll(
              RegExp(
                r'\s+',
              ),
              ' ',
            )
            .trim();

    return cleanedText;
  }

  // Speak response using TTS
  Future<
    void
  >
  speakResponse() async {
    if (!_isConnected) {
      _addLog(
        'Cannot speak: No internet connection',
      );
      return;
    }

    if (_translatedResponse.isEmpty) {
      _addLog(
        'Cannot speak: Empty response',
      );
      return;
    }

    // If already speaking, stop instead
    if (_isReplying) {
      _addLog(
        'Stopping speech',
      );
      await _flutterTts.stop();
      _isReplying =
          false;
      notifyListeners();
      return;
    }

    _isReplying =
        true;
    notifyListeners();

    try {
      // Clean the text for TTS by removing special characters
      String cleanedText = _cleanTextForTTS(
        _translatedResponse,
      );

      _addLog(
        'Speaking cleaned response: "$cleanedText"',
      );
      await _flutterTts.speak(
        cleanedText,
      );
    } catch (
      e
    ) {
      _addLog(
        'TTS error: $e',
      );
      _isReplying =
          false;
      notifyListeners();
    }
  }

  // Copy response to clipboard
  void copyResponse() {
    _addLog(
      'Copied response to clipboard: "$_translatedResponse"',
    );
    // Implemented in the UI using Clipboard.setData
  }

  // Clear logs
  void clearLogs() {
    _logs =
        '';
    _addLog(
      'Logs cleared',
    );
  }

  // Process direct text input
  Future<
    void
  >
  processTextInput(
    String text,
  ) async {
    if (!_isConnected) {
      _addLog(
        'Cannot process: No internet connection',
      );
      return;
    }

    if (text.isEmpty) {
      _addLog(
        'Cannot process: Empty text input',
      );
      return;
    }

    _speechText =
        text;
    _addLog(
      'Processing direct text input: "$_speechText"',
    );

    _isProcessing =
        true;
    notifyListeners();

    try {
      _addLog(
        'Starting processing workflow...',
      );

      // Add user message to the conversation
      _addMessage(
        _speechText,
        true,
        _bypassTranslation,
        false,
      );

      if (_bypassTranslation) {
        // Direct mode: Skip translation and send directly to Gemini
        _addLog(
          'Using direct mode (bypassing translation)',
        );
        _translatedText =
            _speechText; // Use original text

        // Get response from Gemini
        _addLog(
          'Sending untranslated text directly to Gemini',
        );
        await getGeminiResponse();

        // No translation back needed
        _translatedResponse =
            _geminiResponse;
        _addLog(
          'Response received directly from Gemini',
        );

        // Add AI response to the conversation
        _addMessage(
          _translatedResponse,
          false,
          _bypassTranslation,
          false,
        );

        // Speak response
        _addLog(
          'Speaking response',
        );
        speakResponse();
      } else {
        // Standard mode with translation
        _addLog(
          'Using standard mode with translation',
        );

        // 1. Translate Marathi to English
        _addLog(
          'Step 1: Translating from Marathi to English',
        );
        await translateToEnglish(
          _speechText,
        );

        // 2. Get response from Gemini
        _addLog(
          'Step 2: Getting response from Gemini',
        );
        await getGeminiResponse();

        // 3. Translate English response to Marathi
        _addLog(
          'Step 3: Translating response from English to Marathi',
        );
        await translateToMarathi(
          _geminiResponse,
        );

        // 4. Add AI response to the conversation
        _addMessage(
          _translatedResponse,
          false,
          _bypassTranslation,
          false,
        );

        // 5. Speak response
        _addLog(
          'Step 4: Speaking response',
        );
        speakResponse();
      }

      _addLog(
        'Processing completed successfully',
      );
    } catch (
      e
    ) {
      _addLog(
        'Error during processing workflow: $e',
      );
      _addMessage(
        '(Error processing your request: ${e.toString()})',
        false,
        _bypassTranslation,
        true,
      );
    } finally {
      _isProcessing =
          false;
      notifyListeners();
    }
  }

  // Toggle bypass translation mode
  void toggleBypassTranslation() {
    _bypassTranslation =
        !_bypassTranslation;
    _addLog(
      '${_bypassTranslation ? "Enabled" : "Disabled"} direct mode (bypassing translation)',
    );
    notifyListeners();
  }

  // Add message to conversation history
  void _addMessage(
    String text,
    bool isUser,
    bool isDirectMode,
    bool isError,
  ) {
    final int messageIndex =
        _messages.length;
    _messages.add(
      ChatMessage(
        text:
            text,
        isUser:
            isUser,
        isDirectMode:
            isDirectMode,
        isError:
            isError,
      ),
    );
    notifyListeners();

    // Analyze sentiment for user messages after a short delay
    // to avoid interference with other API calls
    if (isUser &&
        !isError) {
      Future.delayed(
        Duration(
          milliseconds:
              500,
        ),
        () {
          analyzeSentiment(
            text,
            messageIndex,
          );
        },
      );
    }
  }

  // Analyze sentiment of a message
  Future<
    void
  >
  analyzeSentiment(
    String text,
    int messageIndex,
  ) async {
    // Don't analyze very short messages or if we're offline
    if (text.length <
            3 ||
        messageIndex <
            0 ||
        messageIndex >=
            _messages.length ||
        !_isConnected) {
      _addLog(
        'Cannot analyze sentiment: Invalid message or no connection',
      );
      return;
    }

    // Prevent multiple simultaneous sentiment analyses
    if (_isAnalyzingSentiment) {
      _addLog(
        'Skipping sentiment analysis: Already analyzing another message',
      );
      return;
    }

    _isAnalyzingSentiment =
        true;

    try {
      final apiKey =
          dotenv.env['GEMINI_API_KEY'] ??
          '';
      if (apiKey.isEmpty) {
        _addLog(
          'Error: Gemini API key is missing',
        );
        return;
      }

      _addLog(
        'Analyzing sentiment for message: "$text"',
      );

      final prompt = """
Analyze the sentiment of the following text, detecting the emotional tone.
Respond with ONLY ONE WORD from these options: positive, negative, neutral, excited, sad, angry, confused, curious, or surprised.
Do not include any explanation, just the single word answer.

TEXT: $text

SENTIMENT:
""";

      final model = GenerativeModel(
        model:
            'gemini-1.5-flash',
        apiKey:
            apiKey,
      );
      final content = [
        Content.text(
          prompt,
        ),
      ];
      final response = await model.generateContent(
        content,
      );

      String
      sentiment =
          (response.text ??
                  'neutral')
              .trim()
              .toLowerCase();
      _addLog(
        'Sentiment detected: $sentiment',
      );

      // Update the message with the sentiment
      final message =
          _messages[messageIndex];
      _messages[messageIndex] = ChatMessage(
        text:
            message.text,
        isUser:
            message.isUser,
        isDirectMode:
            message.isDirectMode,
        isError:
            message.isError,
        timestamp:
            message.timestamp,
        isEdited:
            message.isEdited,
        sentiment:
            sentiment,
      );

      notifyListeners();
    } catch (
      e
    ) {
      _addLog(
        'Error analyzing sentiment: ${_formatErrorMessage(e)}',
      );
    } finally {
      _isAnalyzingSentiment =
          false;
    }
  }

  // Clear conversation history
  void clearConversation() {
    _messages.clear();
    _speechText =
        '';
    _translatedText =
        '';
    _geminiResponse =
        '';
    _translatedResponse =
        '';
    _addLog(
      'Conversation history cleared',
    );
    notifyListeners();
  }

  // Edit and reprocess a message
  Future<
    void
  >
  editAndReprocessMessage(
    String originalMessage,
    String editedMessage,
  ) async {
    _addLog(
      'Editing message: "$originalMessage" -> "$editedMessage"',
    );

    // Find the original message in history
    int messageIndex = _messages.indexWhere(
      (
        msg,
      ) =>
          msg.isUser &&
          msg.text ==
              originalMessage,
    );

    if (messageIndex ==
        -1) {
      _addLog(
        'Original message not found in history',
      );
      return;
    }

    // Update the message text
    final originalDirectMode =
        _messages[messageIndex].isDirectMode;
    _messages[messageIndex] = ChatMessage(
      text:
          editedMessage,
      isUser:
          true,
      isDirectMode:
          originalDirectMode,
      isError:
          false,
      isEdited:
          true,
    );

    // Remove all messages that come after this one
    if (_messages.length >
        messageIndex +
            1) {
      _messages.removeRange(
        messageIndex +
            1,
        _messages.length,
      );
    }

    notifyListeners();

    // Re-analyze sentiment for the edited message
    Future.delayed(
      Duration(
        milliseconds:
            500,
      ),
      () {
        analyzeSentiment(
          editedMessage,
          messageIndex,
        );
      },
    );

    // Reprocess the edited message
    _speechText =
        editedMessage;
    _addLog(
      'Reprocessing edited message: "$editedMessage"',
    );

    // Process the edited message (same logic as processTextInput)
    _isProcessing =
        true;
    notifyListeners();

    try {
      _addLog(
        'Starting processing workflow...',
      );

      if (_bypassTranslation) {
        // Direct mode: Skip translation and send directly to Gemini
        _addLog(
          'Using direct mode (bypassing translation)',
        );
        _translatedText =
            _speechText; // Use original text

        // Get response from Gemini
        _addLog(
          'Sending untranslated text directly to Gemini',
        );
        await getGeminiResponse();

        // No translation back needed
        _translatedResponse =
            _geminiResponse;
        _addLog(
          'Response received directly from Gemini',
        );

        // Add AI response to the conversation
        _addMessage(
          _translatedResponse,
          false,
          _bypassTranslation,
          false,
        );

        // Speak response
        _addLog(
          'Speaking response',
        );
        speakResponse();
      } else {
        // Standard mode with translation
        _addLog(
          'Using standard mode with translation',
        );

        // 1. Translate Marathi to English
        _addLog(
          'Step 1: Translating from Marathi to English',
        );
        await translateToEnglish(
          _speechText,
        );

        // 2. Get response from Gemini
        _addLog(
          'Step 2: Getting response from Gemini',
        );
        await getGeminiResponse();

        // 3. Translate English response to Marathi
        _addLog(
          'Step 3: Translating response from English to Marathi',
        );
        await translateToMarathi(
          _geminiResponse,
        );

        // 4. Add AI response to the conversation
        _addMessage(
          _translatedResponse,
          false,
          _bypassTranslation,
          false,
        );

        // 5. Speak response
        _addLog(
          'Step 4: Speaking response',
        );
        speakResponse();
      }

      _addLog(
        'Processing completed successfully',
      );
    } catch (
      e
    ) {
      _addLog(
        'Error during processing workflow: $e',
      );
      _addMessage(
        '(Error processing your request: ${e.toString()})',
        false,
        _bypassTranslation,
        true,
      );
    } finally {
      _isProcessing =
          false;
      notifyListeners();
    }
  }

  // Summarize the current conversation
  Future<
    String
  >
  summarizeConversation() async {
    _addLog(
      'Summarizing conversation...',
    );

    if (_messages.isEmpty) {
      _addLog(
        'No messages to summarize',
      );
      return "No conversation to summarize yet.";
    }

    if (!_isConnected) {
      _addLog(
        'Cannot summarize: No internet connection',
      );
      return "Cannot summarize: Please check your internet connection.";
    }

    // Setting a local variable instead of modifying state
    bool wasProcessing =
        _isProcessing;
    _isProcessing =
        true;
    // Don't call notifyListeners() here

    try {
      // Format conversation history for the prompt
      final conversationText = _messages
          .map(
            (
              msg,
            ) {
              final role =
                  msg.isUser
                      ? "User"
                      : "Assistant";
              return "$role: ${msg.text}";
            },
          )
          .join(
            "\n\n",
          );

      // Create the summarization prompt
      final prompt = """
Please summarize the following conversation in Marathi. 
Focus on the main topics discussed and key information exchanged.
Keep the summary concise (3-5 points maximum).

IMPORTANT: The summary will be read aloud using text-to-speech, so:
- Use natural, conversational language that sounds good when spoken
- Keep sentences short and clear
- Use simple words that are easy to pronounce
- Avoid complex punctuation or symbols
- Create a flowing narrative that's easy to follow when heard

Use markdown formatting in your summary:
- Use **bold** for important terms or concepts
- Use *italics* for emphasis
- Use bullet points for listing key points

CONVERSATION:
$conversationText

SUMMARY:
""";

      _addLog(
        'Sending summarization request to Gemini',
      );

      final apiKey =
          dotenv.env['GEMINI_API_KEY'] ??
          '';
      if (apiKey.isEmpty) {
        _addLog(
          'Error: Gemini API key is missing',
        );
        _isProcessing =
            wasProcessing; // Restore previous state
        return "Error: API key is missing. Please add your Gemini API key to the .env file.";
      }

      // Use Gemini to generate the summary
      final model = GenerativeModel(
        model:
            'gemini-1.5-flash',
        apiKey:
            apiKey,
      );
      final content = [
        Content.text(
          prompt,
        ),
      ];
      final response = await model.generateContent(
        content,
      );

      final summary =
          response.text ??
          'Could not generate summary';
      _addLog(
        'Summary generated: "$summary"',
      );

      // Ensure summary has markdown formatting
      return _ensureMarkdownFormatting(
        summary,
      );
    } catch (
      e
    ) {
      final errorMessage = _formatErrorMessage(
        e,
      );
      _addLog(
        'Summarization error: $errorMessage',
      );
      return "Error generating summary: $errorMessage";
    } finally {
      _isProcessing =
          wasProcessing; // Restore previous state
      // Don't call notifyListeners() here
    }
  }

  @override
  void dispose() {
    _addLog(
      'Disposing AppProvider',
    );
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }
}
