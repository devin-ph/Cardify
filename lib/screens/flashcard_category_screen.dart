import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final List<String> deckNames = [
    'Academic IELTS',
    'Business English',
    'TOEIC',
  ];
  int selectedDeck = 0;
  final List<List<Flashcard>> allFlashcards = [
    [
      Flashcard(
        image: 'assets/images/ephemeral.png',
        word: 'Ephemeral',
        phonetic: '/ɪˈfem.ər.əl/',
        meaning: 'Ngắn ngủi, phù du',
        example: 'Life is ephemeral, so enjoy every moment.',
      ),
      // Thêm flashcard cho Academic IELTS
    ],
    [
      Flashcard(
        image: 'assets/images/business.png',
        word: 'Synergy',
        phonetic: '/ˈsɪn.ɚ.dʒi/',
        meaning: 'Sức mạnh tổng hợp',
        example: 'The synergy between the teams led to success.',
      ),
      // Thêm flashcard cho Business English
    ],
    [
      Flashcard(
        image: 'assets/images/toeic.png',
        word: 'Comprehend',
        phonetic: '/ˌkɒm.prɪˈhend/',
        meaning: 'Hiểu, lĩnh hội',
        example: 'It is hard to comprehend his accent.',
      ),
      // Thêm flashcard cho TOEIC
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final flashcards = allFlashcards[selectedDeck];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Study Decks',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // Deck list
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: deckNames.length,
                separatorBuilder: (_, _) => SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final isSelected = selectedDeck == index;
                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      setState(() {
                        selectedDeck = index;
                      });
                    },
                    child: Chip(
                      label: Text(deckNames[index]),
                      backgroundColor: isSelected
                          ? Color(0xFF0A5DB6)
                          : Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Color(0xFF0A5DB6),
                        fontWeight: FontWeight.bold,
                      ),
                      avatar: Icon(
                        Icons.school,
                        color: isSelected
                            ? Colors.white
                            : Color.fromARGB(255, 150, 197, 247),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 8),
            // Flashcard
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: 22),
                  Align(
                    alignment: Alignment.topCenter,
                    child: FlipCard(
                      direction: FlipDirection.HORIZONTAL,
                      front: FlashcardFront(
                        flashcard: flashcards[0],
                        width: 420,
                        height: 480,
                      ),
                      back: FlashcardBack(
                        flashcard: flashcards[0],
                        width: 420,
                        height: 480,
                      ),
                    ),
                  ),
                  SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFF0A5DB6),
                              side: BorderSide(
                                color: Color(0xFF0A5DB6),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 27),
                            ),
                            onPressed: () {},
                            child: Text(
                              'Review later',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0A5DB6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 27),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã biết')),
                              );
                            },
                            child: Text(
                              'I know',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Flashcard {
  final String image;
  final String word;
  final String phonetic;
  final String meaning;
  final String example;

  Flashcard({
    required this.image,
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
  });
}

class FlashcardFront extends StatelessWidget {
  final Flashcard flashcard;
  final double width;
  final double height;
  const FlashcardFront({
    super.key,
    required this.flashcard,
    this.width = 320,
    this.height = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(flashcard.image, height: 120),
            SizedBox(height: 32),
            Text(
              flashcard.word,
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              flashcard.phonetic,
              style: TextStyle(fontSize: 20, color: Colors.blueGrey),
            ),
            Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon: Icon(Icons.volume_up, color: Colors.blue, size: 36),
                onPressed: () {
                  // Phát âm thanh
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlashcardBack extends StatelessWidget {
  final Flashcard flashcard;
  final double width;
  final double height;
  const FlashcardBack({
    super.key,
    required this.flashcard,
    this.width = 320,
    this.height = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              flashcard.meaning,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            Text(
              flashcard.example,
              style: TextStyle(fontSize: 20, color: Colors.black54),
            ),
            Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon: Icon(Icons.volume_up, color: Colors.blue, size: 36),
                onPressed: () {
                  // Phát âm thanh
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
