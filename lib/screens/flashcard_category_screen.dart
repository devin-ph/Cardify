import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
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

  bool _containsVocabularyWord(String word, String sentence) {
    final normalizedWord = word.trim().toLowerCase();
    final normalizedSentence = sentence.trim().toLowerCase();
    if (normalizedWord.isEmpty) {
      return false;
    }
    if (normalizedSentence.isEmpty) {
      return true;
    }
    final escapedWord = RegExp.escape(normalizedWord);
    final boundaryPattern = RegExp(
      '(^|[^a-z0-9])' + escapedWord + r'([^a-z0-9]|$)',
      caseSensitive: false,
    );
    return boundaryPattern.hasMatch(normalizedSentence);
  }

  Future<void> _showOptionNotice({
    required String title,
    required String message,
  }) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDeleteImageDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận xóa ảnh'),
          content: const Text('Bạn có chắc muốn xóa ảnh minh họa này không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _openWordOptionsDialog({
    required Flashcard card,
    required String displayTopic,
    SavedCard? existingCard,
  }) async {
    final exampleController = TextEditingController(
      text: existingCard?.example.isNotEmpty == true
          ? existingCard!.example
          : card.example,
    );

    Uint8List? selectedImageBytes = existingCard?.imageBytes ?? card.imageBytes;
    String? selectedImageUrl = existingCard?.imageUrl;
    var removeCurrentImage = false;
    var isSaving = false;
    var isPickingImage = false;
    var saveSucceeded = false;
    var isSheetDismissed = false;

    Future<void> pickImage(
      ImageSource source,
      void Function(void Function()) setModalState,
    ) async {
      setModalState(() {
        isPickingImage = true;
      });
      try {
        if (source == ImageSource.camera) {
          final capturedBytes = await Navigator.of(context).push<Uint8List>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const _QuickReviewCameraCaptureScreen(),
            ),
          );
          if (capturedBytes != null && mounted) {
            if (!isSheetDismissed) {
              setModalState(() {
                selectedImageBytes = capturedBytes;
                selectedImageUrl = null;
                removeCurrentImage = false;
              });
            }
          }
          return;
        }

        final picked = await _imagePicker.pickImage(
          source: source,
          imageQuality: 88,
          maxWidth: 1440,
        );
        if (picked == null || !mounted) {
          return;
        }
        final bytes = await picked.readAsBytes();
        if (!mounted) {
          return;
        }
        if (!isSheetDismissed) {
          setModalState(() {
            selectedImageBytes = bytes;
            selectedImageUrl = null;
            removeCurrentImage = false;
          });
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        await _showOptionNotice(title: 'Không thể chọn ảnh', message: '$error');
      } finally {
        if (mounted && !isSheetDismissed) {
          setModalState(() {
            isPickingImage = false;
          });
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tùy chọn cho từ "${card.word}"',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 72,
                          height: 72,
                          color: Colors.blue[50],
                          child: selectedImageBytes != null
                              ? Image.memory(
                                  selectedImageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : (selectedImageUrl != null &&
                                    selectedImageUrl!.trim().isNotEmpty)
                              ? Image.network(
                                  selectedImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.blueGrey,
                                  ),
                                )
                              : const Icon(
                                  Icons.image_outlined,
                                  color: Colors.blueGrey,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: isPickingImage
                                  ? null
                                  : () => pickImage(
                                      ImageSource.camera,
                                      setModalState,
                                    ),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Chụp ảnh'),
                            ),
                            OutlinedButton.icon(
                              onPressed: isPickingImage
                                  ? null
                                  : () => pickImage(
                                      ImageSource.gallery,
                                      setModalState,
                                    ),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Chọn ảnh'),
                            ),
                            if (selectedImageBytes != null ||
                                (selectedImageUrl != null &&
                                    selectedImageUrl!.trim().isNotEmpty))
                              TextButton.icon(
                                onPressed: isPickingImage
                                    ? null
                                    : () async {
                                        final confirmed =
                                            await _confirmDeleteImageDialog();
                                        if (!confirmed) {
                                          return;
                                        }
                                        if (!isSheetDismissed) {
                                          setModalState(() {
                                            selectedImageBytes = null;
                                            selectedImageUrl = null;
                                            removeCurrentImage = true;
                                          });
                                        }
                                      },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Xóa ảnh'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: exampleController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Ví dụ đặt câu với từ ${card.word}',
                      hintText: 'Ví dụ phải chứa từ ${card.word}',
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final sentence = exampleController.text.trim();
                                if (sentence.isNotEmpty &&
                                    !_containsVocabularyWord(
                                      card.word,
                                      sentence,
                                    )) {
                                  await _showOptionNotice(
                                    title: 'Ví dụ chưa hợp lệ',
                                    message:
                                        'Câu ví dụ phải chứa từ "${card.word}".',
                                  );
                                  return;
                                }

                                if (!isSheetDismissed) {
                                  setModalState(() {
                                    isSaving = true;
                                  });
                                }
                                try {
                                  await _repository.upsertManualCardFromReview(
                                    word: card.word,
                                    meaning: card.meaning,
                                    phonetic: card.phonetic,
                                    example: sentence,
                                    topic: displayTopic,
                                    imageBytes: selectedImageBytes,
                                    existingImageUrl: selectedImageUrl,
                                    removeImage: removeCurrentImage,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  saveSucceeded = true;
                                  Navigator.of(context).pop();
                                } catch (error) {
                                  if (!mounted) {
                                    return;
                                  }
                                  await _showOptionNotice(
                                    title: 'Lưu thất bại',
                                    message: '$error',
                                  );
                                } finally {
                                  if (mounted &&
                                      !saveSucceeded &&
                                      !isSheetDismissed) {
                                    setModalState(() {
                                      isSaving = false;
                                    });
                                  }
                                }
                              },
                        child: const Text('Lưu tùy chọn'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    isSheetDismissed = true;

    if (mounted && saveSucceeded) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        await _showOptionNotice(
          title: 'Thành công',
          message: 'Đã cập nhật từ vựng.',
        );
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    exampleController.dispose();
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
            final savedCardsByWord = {
              for (final card in savedCardsForTopic)
                card.word.trim().toLowerCase(): card,
            };

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
                    example: _exampleForDisplay(card.word, card.example),
                    topic: card.topic,
                    imageBytes: card.imageBytes,
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
                  example: _exampleForDisplay(sample.word, sample.example),
                  topic: sample.topic,
                  imageBytes: sample.imageBytes,
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
                  child: flashcards.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final carouselHeight = (constraints.maxHeight - 220)
                                .clamp(280.0, 500.0);
                            final cardHeight = (carouselHeight - 20).clamp(
                              260.0,
                              480.0,
                            );

                            return Column(
                              children: [
                                Text(
                                  '${safeIndex + 1}/${flashcards.length}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 16),
                                SizedBox(
                                  height: carouselHeight,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.topCenter,
                                      children: List.generate(3, (layer) {
                                        final cardIndex =
                                            (safeIndex + layer) %
                                            flashcards.length;
                                        final card = flashcards[cardIndex];
                                        final wordKey = card.word
                                            .trim()
                                            .toLowerCase();
                                        final isKnown = _repository.isKnown(
                                          wordKey,
                                          topic: displayTopic,
                                        );
                                        final topOffset = (layer * 10.0).clamp(
                                          0.0,
                                          20.0,
                                        );
                                        final sideInset = (layer * 14.0).clamp(
                                          0.0,
                                          28.0,
                                        );

                                        return Positioned(
                                          top: topOffset,
                                          left: sideInset,
                                          right: sideInset,
                                          child: IgnorePointer(
                                            ignoring: layer != 0,
                                            child: Opacity(
                                              opacity: layer == 0
                                                  ? 1.0
                                                  : (layer == 1 ? 0.92 : 0.86),
                                              child: FlipCard(
                                                key: ValueKey(
                                                  'stack-card-$cardIndex-${card.word}',
                                                ),
                                                direction:
                                                    FlipDirection.HORIZONTAL,
                                                front: FlashcardFront(
                                                  flashcard: card,
                                                  isKnown: isKnown,
                                                  onSpeak: () =>
                                                      _speakWord(card.word),
                                                  width: double.infinity,
                                                  height: cardHeight,
                                                ),
                                                back: FlashcardBack(
                                                  flashcard: card,
                                                  isKnown: isKnown,
                                                  onSpeak: () =>
                                                      _speakWord(card.word),
                                                  width: double.infinity,
                                                  height: cardHeight,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).reversed.toList(),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF0A5DB6,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFF0A5DB6),
                                              width: 1.5,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                          onPressed: currentFlashcard == null
                                              ? null
                                              : () => _openWordOptionsDialog(
                                                  card: currentFlashcard,
                                                  displayTopic: displayTopic,
                                                  existingCard:
                                                      currentWordKey == null
                                                      ? null
                                                      : savedCardsByWord[currentWordKey],
                                                ),
                                          icon: const Icon(Icons.tune),
                                          label: const Text(
                                            'Tùy chọn từ hiện tại',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0A5DB6,
                                            ),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
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
                                              _currentCardIndex =
                                                  (_currentCardIndex + 1) %
                                                  flashcards.length;
                                            });
                                          },
                                          child: const Text(
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
                                SizedBox(height: 8),
                              ],
                            );
                          },
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

String _exampleForDisplay(String word, String example) {
  final normalizedWord = word.trim().toLowerCase();
  final normalizedExample = example.trim();
  if (normalizedWord.isEmpty || normalizedExample.isEmpty) {
    return normalizedExample;
  }

  final escapedWord = RegExp.escape(normalizedWord);
  final boundaryPattern = RegExp(
    '(^|[^a-z0-9])' + escapedWord + r'([^a-z0-9]|$)',
    caseSensitive: false,
  );
  return boundaryPattern.hasMatch(normalizedExample.toLowerCase())
      ? normalizedExample
      : '';
}

class Flashcard {
  final String image;
  final Uint8List? imageBytes;
  final String word;
  final String phonetic;
  final String meaning;
  final String example;
  final String topic;

  Flashcard({
    required this.image,
    this.imageBytes,
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
    if (flashcard.imageBytes != null && flashcard.imageBytes!.isNotEmpty) {
      return Image.memory(
        flashcard.imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }

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
            if (flashcard.example.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                flashcard.example,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
            ],
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

  Widget _buildImage() {
    if (flashcard.imageBytes != null && flashcard.imageBytes!.isNotEmpty) {
      return Image.memory(
        flashcard.imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }

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
              flashcard.meaning,
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
              flashcard.word,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (flashcard.example.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                flashcard.example,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
            ],
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

class _QuickReviewCameraCaptureScreen extends StatefulWidget {
  const _QuickReviewCameraCaptureScreen();

  @override
  State<_QuickReviewCameraCaptureScreen> createState() =>
      _QuickReviewCameraCaptureScreenState();
}

class _QuickReviewCameraCaptureScreenState
    extends State<_QuickReviewCameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _initializing = true;
      _errorText = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorText = 'Không tìm thấy camera trên thiết bị';
        });
        return;
      }

      _cameras = cameras;
      await _createController(cameras[_cameraIndex]);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Không thể mở camera: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _createController(CameraDescription description) async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    _controller = controller;
  }

  Future<void> _switchCamera() async {
    if (_capturing || _initializing || _cameras.length < 2) {
      return;
    }
    setState(() {
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
      _initializing = true;
    });
    try {
      await _createController(_cameras[_cameraIndex]);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Không thể đổi camera: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() {
      _capturing = true;
    });
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể chụp ảnh: $error')));
      setState(() {
        _capturing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Chụp ảnh minh họa'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
              tooltip: 'Đổi camera',
            ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : (controller == null || !controller.value.isInitialized)
          ? const Center(
              child: Text(
                'Camera chưa sẵn sàng',
                style: TextStyle(color: Colors.white),
              ),
            )
          : Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _capturing ? null : _capturePhoto,
        child: _capturing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt),
      ),
    );
  }
}
