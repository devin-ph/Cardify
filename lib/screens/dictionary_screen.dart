import 'package:flutter/material.dart';
import 'dart:ui';

class DictionaryScreen extends StatelessWidget {
  final List<Map<String, String>> words;
  const DictionaryScreen({
    super.key,
    this.words = const [
      {
        'image': '',
        'word': 'apple',
        'type': 'noun',
        'meaning': 'quả táo',
        'phonetic': '/ˈæp.əl/',
        'example': 'I eat an apple every day.',
      },
      {
        'image': '',
        'word': 'run',
        'type': 'verb',
        'meaning': 'chạy',
        'phonetic': '/rʌn/',
        'example': 'He can run very fast.',
      },
      {
        'image': '',
        'word': 'beautiful',
        'type': 'adj',
        'meaning': 'đẹp',
        'phonetic': '/ˈbjuː.tɪ.fəl/',
        'example': 'She looked beautiful in that dress.',
      },
      {
        'image': '',
        'word': 'quickly',
        'type': 'adv',
        'meaning': 'nhanh chóng',
        'phonetic': '/ˈkwɪk.li/',
        'example': 'He finished the test quickly.',
      },
      {
        'image': '',
        'word': 'book',
        'type': 'noun',
        'meaning': 'quyển sách',
        'phonetic': '/bʊk/',
        'example': 'She borrowed a book from the library.',
      },
      {
        'image': '',
        'word': 'cat',
        'type': 'noun',
        'meaning': 'con mèo',
        'phonetic': '/kæt/',
        'example': 'The cat sat on the mat.',
      },
      {
        'image': '',
        'word': 'swim',
        'type': 'verb',
        'meaning': 'bơi',
        'phonetic': '/swɪm/',
        'example': 'I like to swim in the sea.',
      },
      {
        'image': '',
        'word': 'quick',
        'type': 'adj',
        'meaning': 'nhanh',
        'phonetic': '/kwɪk/',
        'example': 'Be quick or you\'ll miss the bus.',
      },
      {
        'image': '',
        'word': 'slowly',
        'type': 'adv',
        'meaning': 'một cách chậm rãi',
        'phonetic': '/ˈsləʊ.li/',
        'example': 'He walked slowly to the door.',
      },
      {
        'image': '',
        'word': 'pen',
        'type': 'noun',
        'meaning': 'cây bút',
        'phonetic': '/pen/',
        'example': 'Please pass me the pen.',
      },
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ điển'),
        backgroundColor: Colors.blue[400],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              return InkWell(
                onTap: () {
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Word Detail',
                    barrierColor: Colors.black54,
                    transitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (context, anim1, anim2) {
                      final screenW = MediaQuery.of(context).size.width;
                      final screenH = MediaQuery.of(context).size.height;
                      final maxW = screenW * 0.99;
                      final maxH = screenH * 0.97;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            Navigator.of(context).pop(), // tap outside closes
                        child: Material(
                          type: MaterialType.transparency,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {}, // absorb taps inside card
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxW,
                                  maxHeight: maxH,
                                ),
                                child: Stack(
                                  children: [
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if ((word['image'] ?? '')
                                                  .isNotEmpty)
                                                Image.asset(
                                                  word['image']!,
                                                  height: 180,
                                                  fit: BoxFit.contain,
                                                )
                                              else
                                                Container(
                                                  width: 230,
                                                  height: 230,
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.image,
                                                    size: 88,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              const SizedBox(height: 22),
                                              Text(word['word'] ?? '', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 12),
                                              Text(word['phonetic'] ?? '', style: const TextStyle(fontSize: 24, color: Colors.grey)),
                                              const SizedBox(height: 18),
                                              Text(word['meaning'] ?? '', style: const TextStyle(fontSize: 28)),
                                              const SizedBox(height: 18),
                                              Text(
                                                word['word'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                word['phonetic'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                word['meaning'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                word['example'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.white,
                                        child: IconButton(
                                          icon: const Icon(Icons.arrow_back),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    transitionBuilder: (context, anim1, anim2, child) {
                      final curved = CurvedAnimation(
                        parent: anim1,
                        curve: Curves.easeOutBack,
                      );
                      return Stack(
                        children: [
                          BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 6 * anim1.value,
                              sigmaY: 6 * anim1.value,
                            ),
                            child: Container(
                              color: Colors.black.withOpacity(0),
                            ),
                          ),
                          Center(
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.75,
                                end: 1.0,
                              ).animate(curved),
                              child: FadeTransition(
                                opacity: anim1,
                                child: child,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue[100]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image,
                          color: Colors.blueGrey,
                        ), // Placeholder for image
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  word['word'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    word['type'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              word['meaning'] ?? '',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              word['phonetic'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
