import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/saved_card.dart';
import '../services/saved_cards_repository.dart';

class FlashcardScreen extends StatefulWidget {
  final String? selectedTopic;

  const FlashcardScreen({super.key, this.selectedTopic});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final FlutterTts _tts = FlutterTts();
  final SavedCardsRepository _repository = SavedCardsRepository.instance;
  static const int _targetCardsPerTopic = 50;
  static const List<String> _commonPairs = [
    'Open|Mở',
    'Close|Đóng',
    'Start|Bắt đầu',
    'Finish|Kết thúc',
    'Easy|Dễ',
    'Difficult|Khó',
    'Fast|Nhanh',
    'Slow|Chậm',
    'Hot|Nóng',
    'Cold|Lạnh',
    'Happy|Vui',
    'Sad|Buồn',
    'Strong|Mạnh',
    'Weak|Yếu',
    'Clean|Sạch',
    'Dirty|Bẩn',
    'Safe|An toàn',
    'Dangerous|Nguy hiểm',
    'Important|Quan trọng',
    'Special|Đặc biệt',
    'Simple|Đơn giản',
    'Complex|Phức tạp',
    'Early|Sớm',
    'Late|Muộn',
    'Fresh|Tươi',
    'Dry|Khô',
    'Wet|Ướt',
    'Quiet|Yên tĩnh',
    'Noisy|Ồn ào',
    'Modern|Hiện đại',
    'Classic|Cổ điển',
    'Public|Công cộng',
    'Private|Riêng tư',
    'Available|Có sẵn',
    'Missing|Thiếu',
    'Correct|Đúng',
    'Wrong|Sai',
    'Helpful|Hữu ích',
    'Useful|Có ích',
    'Popular|Phổ biến',
  ];
  static const Map<String, List<String>> _topicExtraPairs = {
    'Đồ gia dụng': [
      'Wardrobe|Tủ quần áo',
      'Drawer|Ngăn kéo',
      'Kettle|Ấm đun nước',
      'Microwave|Lò vi sóng',
      'Refrigerator|Tủ lạnh',
      'Stove|Bếp',
      'Pan|Chảo',
      'Pot|Nồi',
      'Towel|Khăn tắm',
      'Toothbrush|Bàn chải đánh răng',
      'Shampoo|Dầu gội',
      'Soap|Xà phòng',
    ],
    'Thiên nhiên': [
      'Valley|Thung lũng',
      'Desert|Sa mạc',
      'Island|Hòn đảo',
      'Waterfall|Thác nước',
      'Volcano|Núi lửa',
      'Thunder|Sấm',
      'Lightning|Tia chớp',
      'Rainbow|Cầu vồng',
      'Leaf|Lá cây',
      'Branch|Cành cây',
      'Soil|Đất',
      'Sand|Cát',
    ],
    'Công nghệ': [
      'Code|Mã lập trình',
      'Program|Chương trình',
      'Database|Cơ sở dữ liệu',
      'Network|Mạng',
      'Cloud|Đám mây',
      'Password|Mật khẩu',
      'Security|Bảo mật',
      'Update|Cập nhật',
      'Download|Tải xuống',
      'Upload|Tải lên',
      'Device|Thiết bị',
      'Processor|Bộ xử lý',
    ],
    'Đồ ăn': [
      'Vegetable|Rau củ',
      'Fruit|Trái cây',
      'Pork|Thịt heo',
      'Beef|Thịt bò',
      'Chicken|Thịt gà',
      'Shrimp|Tôm',
      'Crab|Cua',
      'Juice|Nước ép',
      'Tea|Trà',
      'Coffee|Cà phê',
      'Honey|Mật ong',
      'Pepper|Tiêu',
    ],
    'Con vật': [
      'Bear|Gấu',
      'Wolf|Sói',
      'Fox|Cáo',
      'Deer|Hươu',
      'Goat|Dê',
      'Donkey|Lừa',
      'Eagle|Đại bàng',
      'Parrot|Vẹt',
      'Dolphin|Cá heo',
      'Whale|Cá voi',
      'Shark|Cá mập',
      'Ant|Kiến',
    ],
    'Phương tiện': [
      'Van|Xe tải nhỏ',
      'Tram|Xe điện',
      'Ferry|Phà',
      'Canoe|Ca nô',
      'Yacht|Du thuyền',
      'Skateboard|Ván trượt',
      'Rollerblade|Giày trượt',
      'Wheelchair|Xe lăn',
      'Cart|Xe đẩy',
      'Rocket|Tên lửa',
      'Jet|Máy bay phản lực',
      'Glider|Tàu lượn',
    ],
    'Hoạt động': [
      'Listen|Lắng nghe',
      'Speak|Nói',
      'Watch|Xem',
      'Think|Suy nghĩ',
      'Build|Xây dựng',
      'Fix|Sửa chữa',
      'Drive|Lái xe',
      'Travel|Du lịch',
      'Practice|Luyện tập',
      'Exercise|Tập thể dục',
      'Relax|Thư giãn',
      'Celebrate|Ăn mừng',
    ],
    'Màu sắc': [
      'Turquoise|Màu ngọc lam',
      'Crimson|Màu đỏ thẫm',
      'Navy|Màu xanh hải quân',
      'Olive|Màu ô liu',
      'Lavender|Màu oải hương',
      'Maroon|Màu đỏ rượu vang',
      'Coral|Màu san hô',
      'Amber|Màu hổ phách',
      'Ivory|Màu ngà',
      'Mint|Màu xanh bạc hà',
      'Peach|Màu đào',
      'Teal|Màu xanh mòng két',
    ],
    'Không gian': [
      'Area|Khu vực',
      'Zone|Vùng',
      'Corner|Góc',
      'Center|Trung tâm',
      'Border|Biên giới',
      'Front|Phía trước',
      'Back|Phía sau',
      'Left|Bên trái',
      'Right|Bên phải',
      'Above|Phía trên',
      'Below|Phía dưới',
      'Middle|Ở giữa',
    ],
    'Thời gian': [
      'Clock|Đồng hồ',
      'Date|Ngày tháng',
      'Schedule|Lịch trình',
      'Deadline|Hạn chót',
      'Moment|Khoảnh khắc',
      'Period|Khoảng thời gian',
      'Century|Thế kỷ',
      'Decade|Thập kỷ',
      'Season|Mùa',
      'Spring|Mùa xuân',
      'Summer|Mùa hè',
      'Winter|Mùa đông',
    ],
  };
  final List<String> deckNames = [
    'Đồ gia dụng',
    'Thiên nhiên',
    'Công nghệ',
    'Đồ ăn',
    'Con vật',
    'Phương tiện',
    'Hoạt động',
    'Màu sắc',
    'Không gian',
    'Thời gian',
  ];
  int selectedDeck = 0;
  int _currentCardIndex = 0;
  final List<List<Flashcard>> allFlashcards = [
    [
      _sampleFlashcard('Chair', 'Ghế'),
      _sampleFlashcard('Table', 'Bàn'),
      _sampleFlashcard('Bed', 'Giường'),
      _sampleFlashcard('Lamp', 'Đèn bàn'),
      _sampleFlashcard('Sofa', 'Ghế sofa'),
      _sampleFlashcard('Cup', 'Cốc'),
      _sampleFlashcard('Plate', 'Đĩa'),
      _sampleFlashcard('Spoon', 'Muỗng'),
      _sampleFlashcard('Fork', 'Nĩa'),
      _sampleFlashcard('Bowl', 'Bát'),
      _sampleFlashcard('Mirror', 'Gương'),
      _sampleFlashcard('Pillow', 'Gối'),
      _sampleFlashcard('Blanket', 'Chăn'),
      _sampleFlashcard('Door', 'Cửa'),
      _sampleFlashcard('Window', 'Cửa sổ'),
    ],
    [
      _sampleFlashcard('Mountain', 'Núi', image: 'assets/images/business.png'),
      _sampleFlashcard('River', 'Sông', image: 'assets/images/business.png'),
      _sampleFlashcard('Forest', 'Rừng', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'Ocean',
        'Đại dương',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Sky', 'Bầu trời', image: 'assets/images/business.png'),
      _sampleFlashcard('Cloud', 'Đám mây', image: 'assets/images/business.png'),
      _sampleFlashcard('Rain', 'Mưa', image: 'assets/images/business.png'),
      _sampleFlashcard('Sun', 'Mặt trời', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'Moon',
        'Mặt trăng',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Star', 'Ngôi sao', image: 'assets/images/business.png'),
      _sampleFlashcard('Lake', 'Hồ', image: 'assets/images/business.png'),
      _sampleFlashcard('Flower', 'Hoa', image: 'assets/images/business.png'),
      _sampleFlashcard('Tree', 'Cây', image: 'assets/images/business.png'),
      _sampleFlashcard('Wind', 'Gió', image: 'assets/images/business.png'),
      _sampleFlashcard('Stone', 'Đá', image: 'assets/images/business.png'),
    ],
    [
      _sampleFlashcard(
        'Computer',
        'Máy tính',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Laptop',
        'Máy tính xách tay',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Phone', 'Điện thoại', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Tablet',
        'Máy tính bảng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Keyboard',
        'Bàn phím',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Mouse',
        'Chuột máy tính',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Screen', 'Màn hình', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Printer', 'Máy in', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Camera', 'Máy ảnh', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Robot', 'Rô bốt', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Internet',
        'Mạng internet',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Software',
        'Phần mềm',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Hardware',
        'Phần cứng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Server', 'Máy chủ', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Application',
        'Ứng dụng',
        image: 'assets/images/toeic.png',
      ),
    ],
    [
      _sampleFlashcard('Apple', 'Quả táo'),
      _sampleFlashcard('Banana', 'Quả chuối'),
      _sampleFlashcard('Orange', 'Quả cam'),
      _sampleFlashcard('Bread', 'Bánh mì'),
      _sampleFlashcard('Rice', 'Cơm'),
      _sampleFlashcard('Noodle', 'Mì'),
      _sampleFlashcard('Soup', 'Súp'),
      _sampleFlashcard('Meat', 'Thịt'),
      _sampleFlashcard('Fish', 'Cá'),
      _sampleFlashcard('Egg', 'Trứng'),
      _sampleFlashcard('Milk', 'Sữa'),
      _sampleFlashcard('Cheese', 'Phô mai'),
      _sampleFlashcard('Sugar', 'Đường'),
      _sampleFlashcard('Salt', 'Muối'),
      _sampleFlashcard('Butter', 'Bơ'),
    ],
    [
      _sampleFlashcard('Cat', 'Mèo', image: 'assets/images/business.png'),
      _sampleFlashcard('Dog', 'Chó', image: 'assets/images/business.png'),
      _sampleFlashcard('Bird', 'Chim', image: 'assets/images/business.png'),
      _sampleFlashcard('Rabbit', 'Thỏ', image: 'assets/images/business.png'),
      _sampleFlashcard('Tiger', 'Hổ', image: 'assets/images/business.png'),
      _sampleFlashcard('Lion', 'Sư tử', image: 'assets/images/business.png'),
      _sampleFlashcard('Elephant', 'Voi', image: 'assets/images/business.png'),
      _sampleFlashcard('Monkey', 'Khỉ', image: 'assets/images/business.png'),
      _sampleFlashcard('Horse', 'Ngựa', image: 'assets/images/business.png'),
      _sampleFlashcard('Cow', 'Bò', image: 'assets/images/business.png'),
      _sampleFlashcard('Pig', 'Heo', image: 'assets/images/business.png'),
      _sampleFlashcard('Sheep', 'Cừu', image: 'assets/images/business.png'),
      _sampleFlashcard('Duck', 'Vịt', image: 'assets/images/business.png'),
      _sampleFlashcard('Chicken', 'Gà', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'Butterfly',
        'Bươm bướm',
        image: 'assets/images/business.png',
      ),
    ],
    [
      _sampleFlashcard('Car', 'Ô tô', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Bus', 'Xe buýt', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Train', 'Tàu hỏa', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Plane', 'Máy bay', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Bike', 'Xe đạp', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Motorbike', 'Xe máy', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Truck', 'Xe tải', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Taxi', 'Xe taxi', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Ship', 'Tàu thủy', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Boat', 'Thuyền', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Helicopter',
        'Trực thăng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Subway',
        'Tàu điện ngầm',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Scooter',
        'Xe tay ga',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Bicycle', 'Xe đạp', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Ambulance',
        'Xe cứu thương',
        image: 'assets/images/toeic.png',
      ),
    ],
    [
      _sampleFlashcard('Run', 'Chạy'),
      _sampleFlashcard('Walk', 'Đi bộ'),
      _sampleFlashcard('Jump', 'Nhảy'),
      _sampleFlashcard('Swim', 'Bơi'),
      _sampleFlashcard('Dance', 'Nhảy múa'),
      _sampleFlashcard('Sing', 'Hát'),
      _sampleFlashcard('Read', 'Đọc'),
      _sampleFlashcard('Write', 'Viết'),
      _sampleFlashcard('Cook', 'Nấu ăn'),
      _sampleFlashcard('Clean', 'Dọn dẹp'),
      _sampleFlashcard('Study', 'Học'),
      _sampleFlashcard('Work', 'Làm việc'),
      _sampleFlashcard('Sleep', 'Ngủ'),
      _sampleFlashcard('Wake', 'Thức dậy'),
      _sampleFlashcard('Play', 'Chơi'),
    ],
    [
      _sampleFlashcard(
        'Blue',
        'Màu xanh dương',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Red', 'Màu đỏ', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'Green',
        'Màu xanh lá',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Yellow',
        'Màu vàng',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Black', 'Màu đen', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'White',
        'Màu trắng',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Orange',
        'Màu cam',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Purple',
        'Màu tím',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Pink', 'Màu hồng', image: 'assets/images/business.png'),
      _sampleFlashcard('Brown', 'Màu nâu', image: 'assets/images/business.png'),
      _sampleFlashcard('Gray', 'Màu xám', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'Gold',
        'Màu vàng kim',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Silver',
        'Màu bạc',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Violet',
        'Màu tím nhạt',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Beige', 'Màu be', image: 'assets/images/business.png'),
    ],
    [
      _sampleFlashcard('House', 'Nhà', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Room', 'Phòng', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Kitchen', 'Nhà bếp', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Bathroom',
        'Phòng tắm',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Garden', 'Khu vườn', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Street', 'Đường phố', image: 'assets/images/toeic.png'),
      _sampleFlashcard('City', 'Thành phố', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Village',
        'Ngôi làng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'School',
        'Trường học',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Hospital',
        'Bệnh viện',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Office', 'Văn phòng', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Market', 'Chợ', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Park', 'Công viên', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Bridge', 'Cây cầu', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Library', 'Thư viện', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Large', 'Lớn', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Small', 'Nhỏ', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Big', 'To', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Near', 'Gần', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Far', 'Xa', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Inside', 'Bên trong', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Outside',
        'Bên ngoài',
        image: 'assets/images/toeic.png',
      ),
    ],
    [
      _sampleFlashcard('Hour', 'Giờ'),
      _sampleFlashcard('Minute', 'Phút'),
      _sampleFlashcard('Second', 'Giây'),
      _sampleFlashcard('Day', 'Ngày'),
      _sampleFlashcard('Week', 'Tuần'),
      _sampleFlashcard('Month', 'Tháng'),
      _sampleFlashcard('Year', 'Năm'),
      _sampleFlashcard('Morning', 'Buổi sáng'),
      _sampleFlashcard('Afternoon', 'Buổi chiều'),
      _sampleFlashcard('Evening', 'Buổi tối'),
      _sampleFlashcard('Night', 'Ban đêm'),
      _sampleFlashcard('Today', 'Hôm nay'),
      _sampleFlashcard('Yesterday', 'Hôm qua'),
      _sampleFlashcard('Tomorrow', 'Ngày mai'),
      _sampleFlashcard('Calendar', 'Lịch'),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _ensureVocabularyCount();
    _repository.watchCards();
  }

  void _ensureVocabularyCount() {
    for (var i = 0; i < allFlashcards.length && i < deckNames.length; i++) {
      final topic = deckNames[i];
      final cards = allFlashcards[i];
      final image = cards.isNotEmpty
          ? cards.first.image
          : 'assets/images/ephemeral.png';
      final existingWords = cards
          .map((card) => card.word.trim().toLowerCase())
          .toSet();

      void addFromPairs(List<String> pairs) {
        for (final pair in pairs) {
          if (cards.length >= _targetCardsPerTopic) {
            break;
          }
          final pieces = pair.split('|');
          if (pieces.length != 2) {
            continue;
          }
          final word = pieces[0].trim();
          final meaning = pieces[1].trim();
          final key = word.toLowerCase();
          if (word.isEmpty || meaning.isEmpty || existingWords.contains(key)) {
            continue;
          }
          cards.add(_sampleFlashcard(word, meaning, image: image));
          existingWords.add(key);
        }
      }

      addFromPairs(_topicExtraPairs[topic] ?? const []);
      addFromPairs(_commonPairs);

      var fillerIndex = 1;
      while (cards.length < _targetCardsPerTopic) {
        final fillerWord = '$topic Word $fillerIndex';
        final key = fillerWord.toLowerCase();
        if (!existingWords.contains(key)) {
          cards.add(
            _sampleFlashcard(
              fillerWord,
              'Từ bổ sung $fillerIndex',
              image: image,
            ),
          );
          existingWords.add(key);
        }
        fillerIndex++;
      }
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  Future<void> _speakWord(String word) async {
    if (word.trim().isEmpty) {
      return;
    }
    await _tts.stop();
    await _tts.speak(word);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine which topic to display
    final displayTopic = widget.selectedTopic ?? deckNames[selectedDeck];
    final topicIndex = deckNames.indexOf(displayTopic);

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<List<SavedCard>>(
          valueListenable: _repository.cardsNotifier,
          builder: (context, cards, _) {
            final savedCardsForTopic = cards
                .where((card) => card.topic == displayTopic)
                .toList();

            final flashcardsFromSaved = savedCardsForTopic
                .map(
                  (card) => Flashcard(
                    image: _resolveFlashcardImage(
                      word: card.word,
                      meaning: card.meaning,
                      topic: displayTopic,
                      imageUrl: card.imageUrl,
                    ),
                    word: card.word,
                    phonetic: card.phonetic,
                    meaning: card.meaning,
                    example: card.example,
                    topic: card.topic,
                  ),
                )
                .toList();

            final sampleCards = topicIndex >= 0
                ? allFlashcards[topicIndex]
                : allFlashcards[0];
            final mergedFlashcards = <Flashcard>[...flashcardsFromSaved];
            final existingWords = flashcardsFromSaved
                .map((card) => card.word.trim().toLowerCase())
                .toSet();
            for (final sample in sampleCards) {
              final key = sample.word.trim().toLowerCase();
              if (!existingWords.contains(key)) {
                mergedFlashcards.add(sample);
                mergedFlashcards[mergedFlashcards.length - 1] = Flashcard(
                  image: _resolveFlashcardImage(
                    word: sample.word,
                    meaning: sample.meaning,
                    topic: displayTopic,
                    imageUrl: sample.image,
                  ),
                  word: sample.word,
                  phonetic: sample.phonetic,
                  meaning: sample.meaning,
                  example: sample.example,
                  topic: sample.topic,
                );
              }
            }

            final flashcards = mergedFlashcards;
            final safeIndex = flashcards.isEmpty
                ? 0
                : _currentCardIndex % flashcards.length;
            final currentFlashcard = flashcards.isEmpty
                ? null
                : flashcards[safeIndex];
            final currentWordKey = currentFlashcard?.word.trim().toLowerCase();
            final isCurrentKnown =
                currentWordKey != null &&
                _repository.isKnown(currentWordKey, topic: displayTopic);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayTopic,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (flashcards.isEmpty)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.library_add,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Chưa có từ nào trong bộ này',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Hãy thêm từ mới từ mục Từ điển',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Text(
                              '${safeIndex + 1}/${flashcards.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 22),
                            Align(
                              alignment: Alignment.topCenter,
                              child: FlipCard(
                                key: ValueKey(
                                  'card-$safeIndex-${currentFlashcard?.word ?? ''}',
                                ),
                                direction: FlipDirection.HORIZONTAL,
                                front: FlashcardFront(
                                  flashcard: currentFlashcard!,
                                  isKnown: isCurrentKnown,
                                  onSpeak: () =>
                                      _speakWord(currentFlashcard.word),
                                  width: 420,
                                  height: 480,
                                ),
                                back: FlashcardBack(
                                  flashcard: currentFlashcard,
                                  isKnown: isCurrentKnown,
                                  onSpeak: () =>
                                      _speakWord(currentFlashcard.word),
                                  width: 420,
                                  height: 480,
                                ),
                              ),
                            ),
                            SizedBox(height: 25),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32.0,
                              ),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 27,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (flashcards.isEmpty) {
                                          return;
                                        }
                                        setState(() {
                                          _currentCardIndex =
                                              (_currentCardIndex + 1) %
                                              flashcards.length;
                                        });
                                      },
                                      child: Text(
                                        'Tiếp',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 27,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (currentWordKey == null) {
                                          return;
                                        }
                                        setState(() {
                                          _repository.markKnown(
                                            currentWordKey,
                                            topic: displayTopic,
                                          );
                                        });
                                      },
                                      child: Text(
                                        'Tôi đã biết',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Flashcard _sampleFlashcard(String word, String meaning, {String image = ''}) {
  return Flashcard(
    image: _resolveFlashcardImage(
      word: word,
      meaning: meaning,
      imageUrl: image,
    ),
    word: word,
    phonetic: '/${word.toLowerCase()}/',
    meaning: meaning,
    example: 'Ví dụ: $word',
  );
}

String _resolveFlashcardImage({
  required String word,
  required String meaning,
  String? topic,
  String? imageUrl,
}) {
  final explicit = imageUrl?.trim() ?? '';
  if (explicit.isNotEmpty &&
      (explicit.startsWith('http://') || explicit.startsWith('https://'))) {
    return explicit;
  }

  final queryParts = <String>[
    word.trim(),
    meaning.trim(),
    if (topic != null && topic.trim().isNotEmpty) topic.trim(),
  ].where((part) => part.isNotEmpty).toList();

  final keyword = Uri.encodeComponent(queryParts.join(' '));
  final seed = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return 'https://loremflickr.com/600/400/$keyword?lock=$seed';
}

class Flashcard {
  final String image;
  final String word;
  final String phonetic;
  final String meaning;
  final String example;
  final String topic;

  Flashcard({
    required this.image,
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
    this.topic = '',
  });
}

class FlashcardFront extends StatelessWidget {
  final Flashcard flashcard;
  final bool isKnown;
  final VoidCallback onSpeak;
  final double width;
  final double height;
  FlashcardFront({
    super.key,
    required this.flashcard,
    required this.isKnown,
    required this.onSpeak,
    this.width = 320,
    this.height = 420,
  });

  Widget _buildImage() {
    final source = flashcard.image.trim();

    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }

    return Image.asset(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: Colors.transparent,
      child: const Icon(
        Icons.auto_stories_rounded,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: isKnown ? const Color(0xFFE7F8ED) : null,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.blue.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _buildImage(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              flashcard.word,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              flashcard.phonetic.trim().isEmpty
                  ? '/${flashcard.word.toLowerCase()}/'
                  : flashcard.phonetic,
              style: const TextStyle(fontSize: 20, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            Text(
              flashcard.meaning,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.blue, size: 36),
                onPressed: onSpeak,
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
  final bool isKnown;
  final VoidCallback onSpeak;
  final double width;
  final double height;
  FlashcardBack({
    super.key,
    required this.flashcard,
    required this.isKnown,
    required this.onSpeak,
    this.width = 320,
    this.height = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: isKnown ? const Color(0xFFE7F8ED) : null,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.blue.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: flashcard.image.trim().startsWith('http')
                      ? Image.network(
                          flashcard.image.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.auto_stories_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.auto_stories_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              flashcard.meaning,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              flashcard.phonetic.trim().isEmpty
                  ? '/${flashcard.word.toLowerCase()}/'
                  : flashcard.phonetic,
              style: const TextStyle(fontSize: 20, color: Colors.blueGrey),
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
                onPressed: onSpeak,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
