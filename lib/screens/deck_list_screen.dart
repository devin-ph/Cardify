import 'package:flutter/material.dart';
import 'flashcard_category_screen.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  String search = '';
  int filterIndex = 0; // 0: All, 1: Recent, 2: Favorites

  final List<Map<String, dynamic>> decks = [
    {
      'icon': Icons.school,
      'title': 'Academic IELTS',
      'desc': 'Vocab for high scores',
      'progress': 0.24,
      'cards': '12/50',
      'favorite': false,
    },
    {
      'icon': Icons.business_center,
      'title': 'Business English',
      'desc': 'Corporate communication',
      'progress': 0.70,
      'cards': '42/60',
      'favorite': true,
    },
    {
      'icon': Icons.flight,
      'title': 'Travel Essentials',
      'desc': 'Navigating the world',
      'progress': 0.16,
      'cards': '5/30',
      'favorite': false,
    },
    {
      'icon': Icons.medical_services,
      'title': 'Medical Vocabulary',
      'desc': 'Clinical terminology',
      'progress': 0.0,
      'cards': '0/45',
      'favorite': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Lọc deck theo search và filter
    List<Map<String, dynamic>> filteredDecks = decks.where((deck) {
      if (filterIndex == 1 && deck['progress'] == 0)
        return false; // Recent: ví dụ chỉ lấy deck có tiến độ
      if (filterIndex == 2 && !deck['favorite']) return false; // Favorites
      if (search.isNotEmpty &&
          !deck['title'].toLowerCase().contains(search.toLowerCase()))
        return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Color(0xFFF6F7FF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (no back button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Study Decks',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  // Avatar nếu muốn
                  // CircleAvatar(...)
                ],
              ),
            ),
            // Search box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search your decks...',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => search = val),
              ),
            ),
            // Filter buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  _buildFilterButton('All', 0),
                  SizedBox(width: 8),
                  _buildFilterButton('Recent', 1),
                  SizedBox(width: 8),
                  _buildFilterButton('Favorites', 2),
                ],
              ),
            ),
            // Deck list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: filteredDecks.length,
                itemBuilder: (context, idx) {
                  final deck = filteredDecks[idx];
                  return _buildDeckCard(deck);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, int idx) {
    final selected = filterIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterIndex = idx),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: selected ? Color(0xFF0A5DB6) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Color(0xFF0A5DB6),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckCard(Map<String, dynamic> deck) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.all(10),
                  child: Icon(deck['icon'], color: Color(0xFF0A5DB6), size: 32),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck['title'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        deck['desc'],
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Icon(
                  deck['favorite'] ? Icons.star : Icons.star_border,
                  color: Color(0xFF0A5DB6),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${deck['cards']} cards mastered',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                Spacer(),
                Text(
                  '${(deck['progress'] * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0A5DB6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            LinearProgressIndicator(
              value: deck['progress'],
              backgroundColor: Color(0xFFE8F0FE),
              color: Color(0xFF0A5DB6),
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0A5DB6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FlashcardScreen()),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Practice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
