import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/voice_chat_service.dart';

enum _VoiceMode { idle, listening, thinking, speaking }

class VoiceChatSessionResult {
  const VoiceChatSessionResult({required this.candidates});

  final List<ChatVocabularyCandidate> candidates;
}

class ChatVocabularyCandidate {
  const ChatVocabularyCandidate({
    required this.topic,
    required this.intentType,
    required this.word,
    required this.phonetic,
    required this.vietnameseMeaning,
    required this.exampleSentence,
    required this.pronunciationGuide,
  });

  final String topic;
  final String intentType;
  final String word;
  final String phonetic;
  final String vietnameseMeaning;
  final String exampleSentence;
  final String pronunciationGuide;

  String get normalizedWord => word.trim().toLowerCase();
}

class AiVoiceChatDialog extends StatefulWidget {
  const AiVoiceChatDialog({super.key});

  @override
  State<AiVoiceChatDialog> createState() => _AiVoiceChatDialogState();
}

class _AiVoiceChatDialogState extends State<AiVoiceChatDialog>
    with SingleTickerProviderStateMixin {
  static const String _aiChatNarratorKey =
      'profile_settings_ai_chat_narrator_enabled';

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final VoiceChatService _chatService = VoiceChatService();

  final List<_ChatItem> _messages = [];
  final List<ChatVocabularyCandidate> _candidates = [];

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  _VoiceMode _mode = _VoiceMode.idle;
  bool _speechReady = false;
  bool _narratorEnabled = true;
  String _listeningText = '';
  int _activeSpeechSessionId = 0;
  int? _submittedSpeechSessionId;
  Map<String, String>? _viVoice;
  Map<String, String>? _enVoice;
  Timer? _silenceTimer;

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pulseController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadNarratorSetting();
    _initSpeech();
    _initTts();
  }

  Future<void> _loadNarratorSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_aiChatNarratorKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _narratorEnabled = enabled ?? _narratorEnabled;
    });
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        if (status == 'notListening' && _mode == _VoiceMode.listening) {
          setState(() {
            _mode = _VoiceMode.idle;
          });
          _updatePulse();
        }
      },
      onError: (error) {
        _pushAIMessage('Khong the nhan dien giong noi: ${error.errorMsg}');
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _speechReady = available;
    });
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.47);
    await _tts.setPitch(1.0);
    await _configurePreferredVoices();
  }

  Future<void> _configurePreferredVoices() async {
    final dynamic rawVoices = await _tts.getVoices;
    if (rawVoices is! List) {
      await _tts.setLanguage('vi-VN');
      return;
    }

    for (final item in rawVoices) {
      if (item is! Map) {
        continue;
      }
      final voice = Map<String, String>.from(
        item.map((key, value) => MapEntry('$key', '$value')),
      );
      final locale = (voice['locale'] ?? '').toLowerCase();
      if (_viVoice == null && locale.startsWith('vi')) {
        _viVoice = voice;
      }
      if (_enVoice == null && locale.startsWith('en')) {
        _enVoice = voice;
      }
    }

    if (_viVoice != null) {
      await _tts.setVoice(_viVoice!);
    } else {
      await _tts.setLanguage('vi-VN');
    }
  }

  Future<void> _speakReply(VoiceChatReply reply) async {
    final speech = reply.response.trim();
    if (speech.isNotEmpty) {
      if (_viVoice != null) {
        await _tts.setVoice(_viVoice!);
      } else {
        await _tts.setLanguage('vi-VN');
      }
      await _tts.speak(speech);
    }

    // Read the English word separately so pronunciation is clearer than reading IPA symbols.
    final englishTerm = reply.englishTerm.trim();
    if (reply.isSavableWord && englishTerm.isNotEmpty) {
      if (_enVoice != null) {
        await _tts.setVoice(_enVoice!);
      } else {
        await _tts.setLanguage('en-US');
      }
      await _tts.speak(englishTerm);
    }
  }

  void _updatePulse() {
    if (_mode == _VoiceMode.listening || _mode == _VoiceMode.speaking) {
      _pulseController.repeat(reverse: true);
    } else if (_mode == _VoiceMode.thinking) {
      _pulseController.repeat();
    } else {
      _pulseController.stop();
    }
  }

  Future<void> _startListening() async {
    if (!_speechReady) {
      _pushAIMessage('Speech-to-text chưa sẵn sàng trên thiết bị này.');
      return;
    }

    if (_speech.isListening) {
      final sessionId = _activeSpeechSessionId;
      await _speech.stop();
      await _submitRecognizedMessageIfNeeded(
        _listeningText,
        sessionId: sessionId,
      );
      return;
    }

    _activeSpeechSessionId++;
    _submittedSpeechSessionId = null;
    setState(() {
      _mode = _VoiceMode.listening;
      _listeningText = '';
    });
    _updatePulse();

    await _speech.listen(
      localeId: 'vi_VN',
      listenMode: ListenMode.confirmation,
      partialResults: true,
      onResult: _onSpeechResult,
    );
  }

  Future<void> _stopListeningAndSend() async {
    if (!_speechReady || _mode != _VoiceMode.listening) return;

    await _speech.stop();
    final textToSend = _listeningText.trim();

    if (textToSend.isNotEmpty) {
      await _sendMessage(textToSend);
    } else {
      setState(() {
        _mode = _VoiceMode.idle;
      });
      _updatePulse();
    }
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _listeningText = result.recognizedWords;
    });
    if (result.finalResult) {
      final sessionId = _activeSpeechSessionId;
      await _speech.stop();
      final submitted = await _submitRecognizedMessageIfNeeded(
        _listeningText,
        sessionId: sessionId,
      );
      if (!submitted) {
        setState(() {
          _mode = _VoiceMode.idle;
        });
        _updatePulse();
      }
    }
  }

  Future<bool> _submitRecognizedMessageIfNeeded(
    String message, {
    required int sessionId,
  }) async {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (_submittedSpeechSessionId == sessionId) {
      return false;
    }

    _submittedSpeechSessionId = sessionId;
    await _sendMessage(normalized);
    return true;
  }

  Future<void> _sendMessage(String message) async {
    setState(() {
      _messages.add(_ChatItem(role: 'user', text: message));
      _mode = _VoiceMode.thinking;
      _listeningText = '';
    });
    _updatePulse();

    final prevMessages = _messages.sublist(0, _messages.length - 1);
    final history = prevMessages
        .skip(prevMessages.length > 6 ? prevMessages.length - 6 : 0)
        .map((item) => {'role': item.role, 'content': item.text})
        .toList();

    try {
      final reply = await _chatService.askAI(
        message: message,
        history: history,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_ChatItem(role: 'assistant', text: reply.response));
        _mode = _narratorEnabled ? _VoiceMode.speaking : _VoiceMode.idle;
      });
      _updatePulse();
      _collectVocabulary(reply);
      if (_narratorEnabled) {
        await _speakReply(reply);
      }
      if (mounted && _mode != _VoiceMode.idle) {
        setState(() {
          _mode = _VoiceMode.idle;
        });
        _updatePulse();
      }
    } catch (error) {
      _pushAIMessage('Co loi khi goi AI: $error');
    }
  }

  void _collectVocabulary(VoiceChatReply reply) {
    if (!reply.isSavableWord) {
      return;
    }

    final candidate = ChatVocabularyCandidate(
      topic: reply.topic,
      intentType: reply.intentType,
      word: reply.englishTerm,
      phonetic: reply.phonetic,
      vietnameseMeaning: reply.vietnameseMeaning,
      exampleSentence: reply.exampleSentence.isNotEmpty
          ? reply.exampleSentence
          : reply.response,
      pronunciationGuide: reply.response,
    );

    final exists = _candidates.any(
      (item) => item.normalizedWord == candidate.normalizedWord,
    );
    if (!exists) {
      _candidates.add(candidate);
    }
  }

  void _pushAIMessage(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _messages.add(_ChatItem(role: 'assistant', text: message));
      _mode = _VoiceMode.idle;
    });
    _updatePulse();
  }

  void _closeDialog() {
    Navigator.of(context).pop(_candidates);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: 420,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Học tập bằng cách giao tiếp với AI 👩‍🏫🗣️',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _closeDialog,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            _buildVoiceOrb(),
            if (_listeningText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Ban dang noi: $_listeningText',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Nhấn giữ mic để nói nhé 👇\nBạn có thể hỏi AI về nghĩa của từ , diễn tả các hành động bạn gặp phải . Chúng tôi sẽ giúp bạn!',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final item = _messages[index];
                          final user = item.role == 'user';
                          return Align(
                            alignment: user
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 280),
                              decoration: BoxDecoration(
                                color: user
                                    ? const Color(0xFFDDF2FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(item.text),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GestureDetector(
                onLongPressStart: (_) => _startListening(),
                onLongPressEnd: (_) => _stopListeningAndSend(),
                onLongPressCancel: () => _stopListeningAndSend(),
                child: AbsorbPointer(
                  child: FloatingActionButton(
                    heroTag: 'voice-chat-mic',
                    onPressed: () {}, // Handled by GestureDetector
                    backgroundColor: _mode == _VoiceMode.listening
                        ? const Color(0xFFEF5350)
                        : const Color(0xFF2D7CFF),
                    child: Icon(
                      _mode == _VoiceMode.listening
                          ? Icons.mic_none
                          : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceOrb() {
    final modeText = switch (_mode) {
      _VoiceMode.idle => 'Nhấn giữ để nói',
      _VoiceMode.listening => 'Đang nghe...',
      _VoiceMode.thinking => 'Đang suy nghĩ...',
      _VoiceMode.speaking => 'AI đang trả lời...',
    };

    final orbColor = switch (_mode) {
      _VoiceMode.idle => const Color(0xFF7A90FF),
      _VoiceMode.listening => const Color(0xFFFF6E6E),
      _VoiceMode.thinking => const Color(0xFFFFB74D),
      _VoiceMode.speaking => const Color(0xFF4DB6AC),
    };

    return Column(
      children: [
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      orbColor.withOpacity(0.95),
                      orbColor.withOpacity(0.65),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: orbColor.withOpacity(0.45),
                      blurRadius: 22,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/onboarding/robot_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(modeText, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ChatItem {
  const _ChatItem({required this.role, required this.text});

  final String role;
  final String text;
}
