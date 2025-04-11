import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:voicegpt/providers/app_provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'
    show
        kDebugMode;

class HomeScreen
    extends
        StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<
    HomeScreen
  >
  createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends
        State<
          HomeScreen
        >
    with
        TickerProviderStateMixin {
  final ScrollController _scrollController =
      ScrollController();
  final ScrollController _logScrollController =
      ScrollController();
  final TextEditingController _textInputController =
      TextEditingController();
  final bool _showLogs =
      false;
  bool _showTextInput =
      false;

  // Animation controllers
  late AnimationController _micAnimationController;
  late AnimationController _waveformAnimationController;
  late AnimationController _welcomeAnimationController;

  // Create a focus node to manage text field focus
  final FocusNode _textFieldFocusNode =
      FocusNode();

  @override
  void initState() {
    super.initState();
    _micAnimationController = AnimationController(
      vsync:
          this,
      duration: const Duration(
        milliseconds:
            300,
      ),
    );

    _waveformAnimationController = AnimationController(
      vsync:
          this,
      duration: const Duration(
        milliseconds:
            1500,
      ),
    )..repeat();

    // Animation for welcome screen
    _welcomeAnimationController = AnimationController(
      vsync:
          this,
      duration: const Duration(
        seconds:
            2,
      ),
    )..forward();

    // Add post-frame callback to scroll to bottom when new messages are added
    WidgetsBinding.instance.addPostFrameCallback(
      (
        _,
      ) {
        final appProvider = Provider.of<
          AppProvider
        >(
          context,
          listen:
              false,
        );

        // Listen for changes to messages
        appProvider.addListener(
          () {
            if (appProvider.messages.isNotEmpty) {
              _scrollToBottom();
            }
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds:
              300,
        ),
        curve:
            Curves.easeOut,
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final appProvider = Provider.of<
      AppProvider
    >(
      context,
    );

    // Start or stop the animation based on listening state
    if (appProvider.isListening &&
        !_micAnimationController.isCompleted) {
      _micAnimationController.forward();
    } else if (!appProvider.isListening &&
        _micAnimationController.isCompleted) {
      _micAnimationController.reverse();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Voice GPT',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle:
            true,
        elevation:
            0,
        actions: [
          // Summary button
          if (appProvider.messages.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.summarize,
                color:
                    Theme.of(
                      context,
                    ).colorScheme.primary,
              ),
              onPressed: () {
                _showSummaryDialog(
                  context,
                  appProvider,
                );
              },
              tooltip:
                  'Summarize Conversation',
            ),
          // Clear conversation button
          if (appProvider.messages.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep,
                color:
                    Theme.of(
                      context,
                    ).colorScheme.primary,
              ),
              onPressed: () {
                _showClearConfirmationDialog(
                  context,
                  appProvider,
                );
              },
              tooltip:
                  'Clear Conversation',
            ),
          // Translation/Direct Mode toggle
          IconButton(
            icon: Icon(
              appProvider.bypassTranslation
                  ? Icons.language
                  : Icons.translate,
              color:
                  Theme.of(
                    context,
                  ).colorScheme.primary,
            ),
            onPressed: () {
              appProvider.toggleBypassTranslation();
              // Show toast
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content: Text(
                    appProvider.bypassTranslation
                        ? 'Direct Mode: Text sent as-is'
                        : 'Translation Mode: Marathi will be translated',
                  ),
                  duration: const Duration(
                    seconds:
                        2,
                  ),
                  behavior:
                      SnackBarBehavior.floating,
                  width:
                      MediaQuery.of(
                        context,
                      ).size.width *
                      0.9,
                ),
              );
            },
            tooltip:
                appProvider.bypassTranslation
                    ? 'Switch to Translation Mode'
                    : 'Switch to Direct Mode',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal:
                  20,
              vertical:
                  10,
            ),
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(
              0.3,
            ),
            child: Row(
              children: [
                Icon(
                  appProvider.isConnected
                      ? Icons.wifi
                      : Icons.wifi_off,
                  color:
                      appProvider.isConnected
                          ? Colors.white
                          : Colors.red,
                ),
                const SizedBox(
                  width:
                      8,
                ),
                Text(
                  appProvider.isConnected
                      ? 'Connected'
                      : 'No Internet Connection',
                  style: TextStyle(
                    color:
                        appProvider.isConnected
                            ? Colors.white
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Chat area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(
                16,
              ),
              child:
                  appProvider.messages.isEmpty
                      ? _buildWelcomeScreen() // Show welcome screen when no messages
                      : SingleChildScrollView(
                        controller:
                            _scrollController,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            // Audio waveform (only shown when listening)
                            if (appProvider.isListening) _buildWaveformVisualizer(),

                            // Recording indicator
                            if (appProvider.isListening)
                              Container(
                                margin: const EdgeInsets.only(
                                  bottom:
                                      20,
                                ),
                                padding: const EdgeInsets.all(
                                  16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    16,
                                  ),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.mic,
                                          color:
                                              Colors.red,
                                        ),
                                        const SizedBox(
                                          width:
                                              8,
                                        ),
                                        Text(
                                          'Recording...',
                                          style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            color:
                                                Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        appProvider.stopListening();
                                      },
                                      icon: Icon(
                                        Icons.stop,
                                        size:
                                            16,
                                      ),
                                      label: Text(
                                        'Stop',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.red,
                                        foregroundColor:
                                            Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              12,
                                          vertical:
                                              8,
                                        ),
                                        minimumSize: Size(
                                          80,
                                          36,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Message history
                            ...appProvider.messages.map(
                              (
                                message,
                              ) => _buildMessageBubble(
                                message.text,
                                isUser:
                                    message.isUser,
                                isDirectMode:
                                    message.isDirectMode,
                                isError:
                                    message.isError,
                                isEdited:
                                    message.isEdited,
                                sentiment:
                                    message.sentiment,
                              ),
                            ),

                            // Processing indicator
                            if (appProvider.isProcessing)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    20.0,
                                  ),
                                  child: Column(
                                    children: [
                                      SpinKitThreeBounce(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        size:
                                            24,
                                      ),
                                      const SizedBox(
                                        height:
                                            16,
                                      ),
                                      Text(
                                        'Processing...',
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
            ),
          ),

          // Bottom control area
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal:
                  20,
              vertical:
                  16,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(
                    context,
                  ).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    0.05,
                  ),
                  blurRadius:
                      10,
                  offset: const Offset(
                    0,
                    -5,
                  ),
                ),
              ],
            ),
            child: Column(
              children: [
                // Text input field (conditionally shown)
                if (_showTextInput)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom:
                          16.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller:
                                _textInputController,
                            focusNode:
                                _textFieldFocusNode,
                            decoration: InputDecoration(
                              hintText:
                                  appProvider.bypassTranslation
                                      ? 'Type in Marathi (Latin script)...'
                                      : 'Type in Marathi...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  20,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal:
                                    16,
                                vertical:
                                    12,
                              ),
                            ),
                            maxLines:
                                1,
                            textInputAction:
                                TextInputAction.send,
                            onSubmitted: (
                              text,
                            ) {
                              if (text.isNotEmpty) {
                                appProvider.processTextInput(
                                  text,
                                );
                                _textInputController.clear();
                                // Maintain focus after sending
                                _textFieldFocusNode.requestFocus();
                              }
                            },
                          ),
                        ),
                        const SizedBox(
                          width:
                              8,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.send,
                          ),
                          onPressed: () {
                            final text =
                                _textInputController.text;
                            if (text.isNotEmpty) {
                              appProvider.processTextInput(
                                text,
                              );
                              _textInputController.clear();
                              // Maintain focus after sending
                              _textFieldFocusNode.requestFocus();
                            }
                          },
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),

                // Button row
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    // Toggle text input button
                    IconButton(
                      icon: Icon(
                        _showTextInput
                            ? Icons.keyboard_hide
                            : Icons.keyboard,
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.primary,
                      ),
                      onPressed: () {
                        setState(
                          () {
                            _showTextInput =
                                !_showTextInput;
                          },
                        );
                      },
                      tooltip:
                          _showTextInput
                              ? 'Hide Keyboard'
                              : 'Show Keyboard',
                    ),

                    // Microphone button with animation
                    AnimatedBuilder(
                      animation:
                          _micAnimationController,
                      builder: (
                        context,
                        child,
                      ) {
                        return GestureDetector(
                          onTap: () {
                            if (appProvider.isListening) {
                              appProvider.stopListening();
                            } else {
                              appProvider.startListening();
                            }
                          },
                          child: Container(
                            width:
                                60,
                            height:
                                60,
                            decoration: BoxDecoration(
                              shape:
                                  _micAnimationController.value >
                                          0.5
                                      ? BoxShape.rectangle
                                      : BoxShape.circle,
                              borderRadius:
                                  _micAnimationController.value >
                                          0.5
                                      ? BorderRadius.circular(
                                        16,
                                      )
                                      : null,
                              color:
                                  appProvider.isListening
                                      ? Colors.red.withOpacity(
                                        0.2,
                                      )
                                      : Theme.of(
                                        context,
                                      ).colorScheme.surface,
                              border: Border.all(
                                color:
                                    appProvider.isListening
                                        ? Colors.red.withOpacity(
                                          0.8,
                                        )
                                        : Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(
                                          0.5,
                                        ),
                                width:
                                    2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                appProvider.isListening
                                    ? Icons.stop
                                    : Icons.mic,
                                color:
                                    appProvider.isListening
                                        ? Colors.red
                                        : Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                size:
                                    28,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget for audio waveform visualization
  Widget _buildWaveformVisualizer() {
    return Container(
      height:
          100,
      margin: const EdgeInsets.only(
        bottom:
            20,
      ),
      child: AnimatedBuilder(
        animation:
            _waveformAnimationController,
        builder: (
          context,
          child,
        ) {
          return Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
            children: List.generate(
              10,
              (
                index,
              ) {
                // Create random but smooth heights using sine waves
                final height =
                    20 +
                    40 *
                        math
                            .sin(
                              (_waveformAnimationController.value *
                                      math.pi *
                                      2) +
                                  (index /
                                      3),
                            )
                            .abs();

                return Container(
                  width:
                      6,
                  height:
                      height,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(
                          context,
                        ).colorScheme.primary,
                    borderRadius: BorderRadius.circular(
                      3,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(
    String message, {
    required bool isUser,
    bool isDirectMode =
        false,
    bool isError =
        false,
    bool isEdited =
        false,
    String? sentiment,
  }) {
    // Check if message is an error message
    final bool
    isErrorMessage =
        isError ||
        (message.startsWith(
              '(',
            ) &&
            message.endsWith(
              ')',
            ));

    return Align(
      alignment:
          isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical:
              8,
        ),
        padding: const EdgeInsets.all(
          16,
        ),
        decoration: BoxDecoration(
          color:
              isErrorMessage
                  ? Theme.of(
                    context,
                  ).colorScheme.error.withOpacity(
                    0.1,
                  )
                  : isUser
                  ? Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(
                    0.1,
                  )
                  : Theme.of(
                    context,
                  ).colorScheme.secondary.withOpacity(
                    0.1,
                  ),
          borderRadius: BorderRadius.circular(
            16,
          ),
        ),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(
                context,
              ).size.width *
              0.8,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      isErrorMessage
                          ? 'System Message'
                          : (isUser
                              ? 'You'
                              : 'GPT'),
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color:
                            isErrorMessage
                                ? Theme.of(
                                  context,
                                ).colorScheme.error
                                : isUser
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.secondary,
                      ),
                    ),
                    if (!isErrorMessage &&
                        isDirectMode) ...[
                      const SizedBox(
                        width:
                            8,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal:
                              8,
                          vertical:
                              2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(
                              0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          'Direct',
                          style: TextStyle(
                            fontSize:
                                10,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],

                    // Sentiment indicator
                    if (!isErrorMessage &&
                        isUser &&
                        sentiment !=
                            null) ...[
                      const SizedBox(
                        width:
                            8,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal:
                              6,
                          vertical:
                              2,
                        ),
                        decoration: BoxDecoration(
                          color: _getSentimentColor(
                            sentiment,
                          ).withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                          border: Border.all(
                            color: _getSentimentColor(
                              sentiment,
                            ).withOpacity(
                              0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              _getSentimentIcon(
                                sentiment,
                              ),
                              size:
                                  12,
                              color: _getSentimentColor(
                                sentiment,
                              ),
                            ),
                            const SizedBox(
                              width:
                                  4,
                            ),
                            Text(
                              sentiment,
                              style: TextStyle(
                                fontSize:
                                    10,
                                fontWeight:
                                    FontWeight.bold,
                                color: _getSentimentColor(
                                  sentiment,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Action buttons row
                Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    // Speaker button (only for assistant messages)
                    if (!isUser &&
                        !isErrorMessage)
                      InkWell(
                        onTap: () {
                          final appProvider = Provider.of<
                            AppProvider
                          >(
                            context,
                            listen:
                                false,
                          );
                          appProvider.speakResponse();
                        },
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            8,
                          ),
                          child: Icon(
                            Provider.of<
                                  AppProvider
                                >(
                                  context,
                                ).isReplying
                                ? Icons.stop
                                : Icons.volume_up,
                            size:
                                22,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(
                              0.8,
                            ),
                          ),
                        ),
                      ),

                    // Copy button (only for assistant messages)
                    if (!isUser &&
                        !isErrorMessage)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  message,
                            ),
                          );
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Response copied to clipboard',
                              ),
                              duration: Duration(
                                seconds:
                                    2,
                              ),
                            ),
                          );
                          Provider.of<
                            AppProvider
                          >(
                            context,
                            listen:
                                false,
                          ).copyResponse();
                        },
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            8,
                          ),
                          child: Icon(
                            Icons.copy,
                            size:
                                22,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(
                              0.8,
                            ),
                          ),
                        ),
                      ),

                    // Edit button for user messages
                    if (isUser &&
                        !isErrorMessage)
                      InkWell(
                        onTap: () {
                          _showEditDialog(
                            message,
                          );
                        },
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            8,
                          ),
                          child: Icon(
                            Icons.edit,
                            size:
                                22,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(
                              0.8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(
              height:
                  4,
            ),
            // Use Markdown widget instead of Text for message content
            isErrorMessage
                ? Text(
                  // Remove parentheses from error messages
                  message.substring(
                    1,
                    message.length -
                        1,
                  ),
                  style: TextStyle(
                    fontSize:
                        16,
                    color:
                        Theme.of(
                          context,
                        ).colorScheme.error,
                  ),
                )
                : MarkdownBody(
                  data:
                      message,
                  selectable:
                      true,
                  softLineBreak:
                      true,
                  fitContent:
                      false,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize:
                          16,
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.onSurface,
                    ),
                    strong: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.onSurface,
                    ),
                    em: TextStyle(
                      fontStyle:
                          FontStyle.italic,
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.onSurface,
                    ),
                    code: TextStyle(
                      fontFamily:
                          'monospace',
                      backgroundColor:
                          Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        8,
                      ),
                    ),
                    textAlign:
                        WrapAlignment.start,
                    h1Align:
                        WrapAlignment.start,
                    h2Align:
                        WrapAlignment.start,
                    h3Align:
                        WrapAlignment.start,
                  ),
                ),
            if (isEdited) ...[
              const SizedBox(
                height:
                    4,
              ),
              Text(
                '(edited)',
                style: TextStyle(
                  fontSize:
                      12,
                  fontStyle:
                      FontStyle.italic,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(
                    0.5,
                  ),
                ),
              ),
            ],
            if (isErrorMessage) ...[
              const SizedBox(
                height:
                    12,
              ),
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.settings,
                ),
                label: const Text(
                  'Speech Settings',
                ),
                onPressed: () {
                  // Open system speech settings
                  showDialog(
                    context:
                        context,
                    builder:
                        (
                          context,
                        ) => AlertDialog(
                          title: const Text(
                            'Speech Recognition Tips',
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: const [
                                Text(
                                  'To improve speech recognition:',
                                ),
                                SizedBox(
                                  height:
                                      8,
                                ),
                                Text(
                                  '• Ensure Marathi is enabled in system settings',
                                ),
                                Text(
                                  '• Speak clearly and at a moderate pace',
                                ),
                                Text(
                                  '• Reduce background noise',
                                ),
                                Text(
                                  '• Try using Hindi as a fallback if Marathi fails',
                                ),
                                Text(
                                  '• Try Direct Mode for transliterated Marathi (Latin script)',
                                ),
                                Text(
                                  '• Check your device\'s microphone permissions',
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed:
                                  () =>
                                      Navigator.of(
                                        context,
                                      ).pop(),
                              child: const Text(
                                'OK',
                              ),
                            ),
                          ],
                        ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isActive =
        false,
  }) {
    return GestureDetector(
      onTap:
          onPressed,
      child: Container(
        width:
            60,
        height:
            60,
        decoration: BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              isActive
                  ? color.withOpacity(
                    0.1,
                  )
                  : Theme.of(
                    context,
                  ).colorScheme.surface,
          border: Border.all(
            color: color.withOpacity(
              0.5,
            ),
            width:
                2,
          ),
        ),
        child: Icon(
          icon,
          color:
              color,
          size:
              28,
        ),
      ),
    );
  }

  // Show confirmation dialog before clearing conversation
  void _showClearConfirmationDialog(
    BuildContext context,
    AppProvider appProvider,
  ) {
    showDialog(
      context:
          context,
      builder:
          (
            context,
          ) => AlertDialog(
            title: const Text(
              'Clear Conversation',
            ),
            content: const Text(
              'Are you sure you want to clear the entire conversation history?',
            ),
            actions: [
              TextButton(
                onPressed:
                    () =>
                        Navigator.of(
                          context,
                        ).pop(),
                child: const Text(
                  'Cancel',
                ),
              ),
              TextButton(
                onPressed: () {
                  appProvider.clearConversation();
                  Navigator.of(
                    context,
                  ).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(
                        context,
                      ).colorScheme.error,
                ),
                child: const Text(
                  'Clear',
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _logScrollController.dispose();
    _textInputController.dispose();
    _micAnimationController.dispose();
    _waveformAnimationController.dispose();
    _welcomeAnimationController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // Show dialog to edit a message
  void _showEditDialog(
    String originalMessage,
  ) {
    final TextEditingController editController = TextEditingController(
      text:
          originalMessage,
    );
    final appProvider = Provider.of<
      AppProvider
    >(
      context,
      listen:
          false,
    );

    showDialog(
      context:
          context,
      builder:
          (
            context,
          ) => AlertDialog(
            title: const Text(
              'Edit Message',
            ),
            content: TextField(
              controller:
                  editController,
              maxLines:
                  5,
              minLines:
                  1,
              decoration: InputDecoration(
                hintText:
                    'Edit your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              autofocus:
                  true,
            ),
            actions: [
              TextButton(
                onPressed:
                    () =>
                        Navigator.of(
                          context,
                        ).pop(),
                child: const Text(
                  'Cancel',
                ),
              ),
              TextButton(
                onPressed: () {
                  final editedText =
                      editController.text.trim();
                  if (editedText.isNotEmpty &&
                      editedText !=
                          originalMessage) {
                    appProvider.editAndReprocessMessage(
                      originalMessage,
                      editedText,
                    );
                  }
                  Navigator.of(
                    context,
                  ).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(
                        context,
                      ).colorScheme.primary,
                ),
                child: const Text(
                  'Update & Send',
                ),
              ),
            ],
          ),
    );
  }

  // Show summary dialog
  void _showSummaryDialog(
    BuildContext context,
    AppProvider appProvider,
  ) async {
    // Create the Future outside of the dialog build
    final Future<
      String
    >
    summaryFuture =
        appProvider.summarizeConversation();

    showDialog(
      context:
          context,
      barrierDismissible:
          false,
      builder:
          (
            context,
          ) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                16,
              ),
            ),
            child: Container(
              width: math.min(
                MediaQuery.of(
                      context,
                    ).size.width *
                    0.9,
                450,
              ),
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(
                      context,
                    ).size.height *
                    0.7,
              ),
              padding: const EdgeInsets.all(
                16,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: TextStyle(
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(
                    height:
                        16,
                  ),
                  Flexible(
                    child: FutureBuilder<
                      String
                    >(
                      future:
                          summaryFuture, // Use the pre-created Future
                      builder: (
                        context,
                        snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(
                                  height:
                                      16,
                                ),
                                Text(
                                  'Generating summary...',
                                ),
                              ],
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.error,
                            ),
                          );
                        } else {
                          final summary =
                              snapshot.data ??
                              'No summary available';
                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: MarkdownBody(
                                    data:
                                        summary,
                                    selectable:
                                        true,
                                    softLineBreak:
                                        true,
                                    fitContent:
                                        false,
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(
                                        fontSize:
                                            16,
                                      ),
                                      strong: TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                      em: const TextStyle(
                                        fontStyle:
                                            FontStyle.italic,
                                      ),
                                      listBullet: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                      code: TextStyle(
                                        fontFamily:
                                            'monospace',
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainerHighest,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign:
                                          WrapAlignment.start,
                                      h1Align:
                                          WrapAlignment.start,
                                      h2Align:
                                          WrapAlignment.start,
                                      h3Align:
                                          WrapAlignment.start,
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment:
                                    Alignment.bottomRight,
                                child: TextButton.icon(
                                  icon: const Icon(
                                    Icons.copy,
                                    size:
                                        16,
                                  ),
                                  label: const Text(
                                    'Copy',
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text:
                                            summary,
                                      ),
                                    );
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Summary copied to clipboard',
                                        ),
                                        duration: Duration(
                                          seconds:
                                              2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            () =>
                                Navigator.of(
                                  context,
                                ).pop(),
                        child: const Text(
                          'Close',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Get appropriate icon for sentiment
  IconData _getSentimentIcon(
    String sentiment,
  ) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Icons.sentiment_satisfied_rounded;
      case 'negative':
        return Icons.sentiment_dissatisfied_rounded;
      case 'neutral':
        return Icons.sentiment_neutral_rounded;
      case 'excited':
        return Icons.emoji_emotions_rounded;
      case 'sad':
        return Icons.sentiment_very_dissatisfied_rounded;
      case 'angry':
        return Icons.mood_bad_rounded;
      case 'confused':
        return Icons.sentiment_neutral_rounded;
      case 'curious':
        return Icons.psychology_rounded;
      case 'surprised':
        return Icons.sentiment_very_satisfied_rounded;
      default:
        return Icons.psychology_rounded;
    }
  }

  // Get appropriate color for sentiment
  Color _getSentimentColor(
    String sentiment,
  ) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      case 'neutral':
        return Colors.grey;
      case 'excited':
        return Colors.amber;
      case 'sad':
        return Colors.blue;
      case 'angry':
        return Colors.deepOrange;
      case 'confused':
        return Colors.purple;
      case 'curious':
        return Colors.teal;
      case 'surprised':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  // Welcome screen widget when app first loads
  Widget _buildWelcomeScreen() {
    return AnimatedBuilder(
      animation:
          _welcomeAnimationController,
      builder: (
        context,
        child,
      ) {
        final slideAnimation = Tween<
          Offset
        >(
          begin: const Offset(
            0,
            0.2,
          ),
          end:
              Offset.zero,
        ).animate(
          CurvedAnimation(
            parent:
                _welcomeAnimationController,
            curve:
                Curves.easeOutCubic,
          ),
        );

        final fadeAnimation = Tween<
          double
        >(
          begin:
              0.0,
          end:
              1.0,
        ).animate(
          CurvedAnimation(
            parent:
                _welcomeAnimationController,
            curve:
                Curves.easeOut,
          ),
        );

        return FadeTransition(
          opacity:
              fadeAnimation,
          child: SlideTransition(
            position:
                slideAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Container(
                    width:
                        120,
                    height:
                        120,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                      shape:
                          BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.record_voice_over,
                      size:
                          60,
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(
                    height:
                        32,
                  ),
                  Text(
                    'Welcome to Voice GPT',
                    style: TextStyle(
                      fontSize:
                          24,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(
                    height:
                        16,
                  ),
                  Card(
                    elevation:
                        4,
                    margin: const EdgeInsets.symmetric(
                      horizontal:
                          32,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16.0,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Tap the microphone button below to start speaking in Marathi',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              fontSize:
                                  16,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(
                            height:
                                16,
                          ),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size:
                                    16,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.primary,
                              ),
                              const SizedBox(
                                width:
                                    8,
                              ),
                              Flexible(
                                child: Text(
                                  'You can also type by tapping the keyboard icon',
                                  style: TextStyle(
                                    fontSize:
                                        14,
                                    fontStyle:
                                        FontStyle.italic,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height:
                        24,
                  ),
                  Icon(
                    Icons.arrow_downward,
                    size:
                        32,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(
                      0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
