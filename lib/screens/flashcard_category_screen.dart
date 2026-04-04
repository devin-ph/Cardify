import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_card.dart';
import '../services/saved_cards_repository.dart';

class FlashcardScreen extends StatefulWidget {
  final String? selectedTopic;
  final bool showOnlyTrackedWords;

  const FlashcardScreen({
    super.key,
    this.selectedTopic,
    this.showOnlyTrackedWords = false,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  static const String _postponedWordsStoragePrefix =
      'practice_postponed_words_v1';
  static const String _autoPlaySettingKey =
      'profile_settings_auto_play_enabled';
  final FlutterTts _tts = FlutterTts();
  final SavedCardsRepository _repository = SavedCardsRepository.instance;
  final ImagePicker _imagePicker = ImagePicker();
  late final PageController _pageController;
  static const int _targetCardsPerTopic = 50;
  static const List<String> _commonPairs = [
    'Open|Mß╗ƒ',
    'Close|─É├│ng',
    'Start|Bß║»t ─æß║ºu',
    'Finish|Kß║┐t th├║c',
    'Easy|Dß╗à',
    'Difficult|Kh├│',
    'Fast|Nhanh',
    'Slow|Chß║¡m',
    'Hot|N├│ng',
    'Cold|Lß║ính',
    'Happy|Vui',
    'Sad|Buß╗ôn',
    'Strong|Mß║ính',
    'Weak|Yß║┐u',
    'Clean|Sß║ích',
    'Dirty|Bß║⌐n',
    'Safe|An to├án',
    'Dangerous|Nguy hiß╗âm',
    'Important|Quan trß╗ìng',
    'Special|─Éß║╖c biß╗çt',
    'Simple|─É╞ín giß║ún',
    'Complex|Phß╗⌐c tß║íp',
    'Early|Sß╗¢m',
    'Late|Muß╗Ön',
    'Fresh|T╞░╞íi',
    'Dry|Kh├┤',
    'Wet|╞»ß╗¢t',
    'Quiet|Y├¬n t─⌐nh',
    'Noisy|ß╗Æn ├áo',
    'Modern|Hiß╗çn ─æß║íi',
    'Classic|Cß╗ò ─æiß╗ân',
    'Public|C├┤ng cß╗Öng',
    'Private|Ri├¬ng t╞░',
    'Available|C├│ sß║╡n',
    'Missing|Thiß║┐u',
    'Correct|─É├║ng',
    'Wrong|Sai',
    'Helpful|Hß╗»u ├¡ch',
    'Useful|C├│ ├¡ch',
    'Popular|Phß╗ò biß║┐n',
  ];
  static const Map<String, List<String>> _topicExtraPairs = {
    '─Éß╗ô gia dß╗Ñng': [
      'Wardrobe|Tß╗º quß║ºn ├ío',
      'Drawer|Ng─ân k├⌐o',
      'Kettle|ß║ñm ─æun n╞░ß╗¢c',
      'Microwave|L├▓ vi s├│ng',
      'Refrigerator|Tß╗º lß║ính',
      'Stove|Bß║┐p',
      'Pan|Chß║úo',
      'Pot|Nß╗ôi',
      'Towel|Kh─ân tß║»m',
      'Toothbrush|B├án chß║úi ─æ├ính r─âng',
      'Shampoo|Dß║ºu gß╗Öi',
      'Soap|X├á ph├▓ng',
    ],
    'Thi├¬n nhi├¬n': [
      'Valley|Thung l┼⌐ng',
      'Desert|Sa mß║íc',
      'Island|H├▓n ─æß║úo',
      'Waterfall|Th├íc n╞░ß╗¢c',
      'Volcano|N├║i lß╗¡a',
      'Thunder|Sß║Ñm',
      'Lightning|Tia chß╗¢p',
      'Rainbow|Cß║ºu vß╗ông',
      'Leaf|L├í c├óy',
      'Branch|C├ánh c├óy',
      'Soil|─Éß║Ñt',
      'Sand|C├ít',
    ],
    'C├┤ng nghß╗ç': [
      'Code|M├ú lß║¡p tr├¼nh',
      'Program|Ch╞░╞íng tr├¼nh',
      'Database|C╞í sß╗ƒ dß╗» liß╗çu',
      'Network|Mß║íng',
      'Cloud|─É├ím m├óy',
      'Password|Mß║¡t khß║⌐u',
      'Security|Bß║úo mß║¡t',
      'Update|Cß║¡p nhß║¡t',
      'Download|Tß║úi xuß╗æng',
      'Upload|Tß║úi l├¬n',
      'Device|Thiß║┐t bß╗ï',
      'Processor|Bß╗Ö xß╗¡ l├╜',
    ],
    '─Éß╗ô ─ân': [
      'Vegetable|Rau cß╗º',
      'Fruit|Tr├íi c├óy',
      'Pork|Thß╗ït heo',
      'Beef|Thß╗ït b├▓',
      'Chicken|Thß╗ït g├á',
      'Shrimp|T├┤m',
      'Crab|Cua',
      'Juice|N╞░ß╗¢c ├⌐p',
      'Tea|Tr├á',
      'Coffee|C├á ph├¬',
      'Honey|Mß║¡t ong',
      'Pepper|Ti├¬u',
    ],
    'Con vß║¡t': [
      'Bear|Gß║Ñu',
      'Wolf|S├│i',
      'Fox|C├ío',
      'Deer|H╞░╞íu',
      'Goat|D├¬',
      'Donkey|Lß╗½a',
      'Eagle|─Éß║íi b├áng',
      'Parrot|Vß║╣t',
      'Dolphin|C├í heo',
      'Whale|C├í voi',
      'Shark|C├í mß║¡p',
      'Ant|Kiß║┐n',
    ],
    'Ph╞░╞íng tiß╗çn': [
      'Van|Xe tß║úi nhß╗Å',
      'Tram|Xe ─æiß╗çn',
      'Ferry|Ph├á',
      'Canoe|Ca n├┤',
      'Yacht|Du thuyß╗ün',
      'Skateboard|V├ín tr╞░ß╗út',
      'Rollerblade|Gi├áy tr╞░ß╗út',
      'Wheelchair|Xe l─ân',
      'Cart|Xe ─æß║⌐y',
      'Rocket|T├¬n lß╗¡a',
      'Jet|M├íy bay phß║ún lß╗▒c',
      'Glider|T├áu l╞░ß╗ún',
    ],
    'Hoß║ít ─æß╗Öng': [
      'Listen|Lß║»ng nghe',
      'Speak|N├│i',
      'Watch|Xem',
      'Think|Suy ngh─⌐',
      'Build|X├óy dß╗▒ng',
      'Fix|Sß╗¡a chß╗»a',
      'Drive|L├íi xe',
      'Travel|Du lß╗ïch',
      'Practice|Luyß╗çn tß║¡p',
      'Exercise|Tß║¡p thß╗â dß╗Ñc',
      'Relax|Th╞░ gi├ún',
      'Celebrate|─én mß╗½ng',
    ],
    'M├áu sß║»c': [
      'Turquoise|M├áu ngß╗ìc lam',
      'Crimson|M├áu ─æß╗Å thß║½m',
      'Navy|M├áu xanh hß║úi qu├ón',
      'Olive|M├áu ├┤ liu',
      'Lavender|M├áu oß║úi h╞░╞íng',
      'Maroon|M├áu ─æß╗Å r╞░ß╗úu vang',
      'Coral|M├áu san h├┤',
      'Amber|M├áu hß╗ò ph├ích',
      'Ivory|M├áu ng├á',
      'Mint|M├áu xanh bß║íc h├á',
      'Peach|M├áu ─æ├áo',
      'Teal|M├áu xanh m├▓ng k├⌐t',
    ],
    'Kh├┤ng gian': [
      'Area|Khu vß╗▒c',
      'Zone|V├╣ng',
      'Corner|G├│c',
      'Center|Trung t├óm',
      'Border|Bi├¬n giß╗¢i',
      'Front|Ph├¡a tr╞░ß╗¢c',
      'Back|Ph├¡a sau',
      'Left|B├¬n tr├íi',
      'Right|B├¬n phß║úi',
      'Above|Ph├¡a tr├¬n',
      'Below|Ph├¡a d╞░ß╗¢i',
      'Middle|ß╗₧ giß╗»a',
    ],
    'Thß╗¥i gian': [
      'Clock|─Éß╗ông hß╗ô',
      'Date|Ng├áy th├íng',
      'Schedule|Lß╗ïch tr├¼nh',
      'Deadline|Hß║ín ch├│t',
      'Moment|Khoß║únh khß║»c',
      'Period|Khoß║úng thß╗¥i gian',
      'Century|Thß║┐ kß╗╖',
      'Decade|Thß║¡p kß╗╖',
      'Season|M├╣a',
      'Spring|M├╣a xu├ón',
      'Summer|M├╣a h├¿',
      'Winter|M├╣a ─æ├┤ng',
    ],
  };
  final List<String> deckNames = [
    'Đồ điện tử',
    'Đồ nội thất',
    'Động vật',
    'Thiên nhiên',
    'Công nghệ',
    'Học tập',
    'Đồ ăn',
    'Phương tiện',
  ];
  static const Map<String, int> _sampleDeckIndexByTopic = {
    'Đồ điện tử': 2,
    'Đồ nội thất': 0,
    'Động vật': 4,
    'Thiên nhiên': 1,
    'Công nghệ': 2,
    'Học tập': 8,
    'Đồ ăn': 3,
    'Phương tiện': 5,
  };
  int selectedDeck = 0;
  int _currentCardIndex = 0;
  bool _isPracticeMode = false;
  bool _autoPlayPronunciationEnabled = false;
  String? _lastAutoSpokenCardKey;
  DateTime? _practiceStartedAt;
  String? _recentlyMarkedKnownWordKey;
  String? _recentlyPostponedWordKey;
  final List<String> _postponedWordKeys = [];
  String? _loadedPostponedTopic;
  bool _loadingPostponedWords = false;
  final Set<String> _locallyKnownWordKeys = <String>{};
  final List<List<Flashcard>> allFlashcards = [
    [
      _sampleFlashcard('Chair', 'Ghß║┐'),
      _sampleFlashcard('Table', 'B├án'),
      _sampleFlashcard('Bed', 'Gi╞░ß╗¥ng'),
      _sampleFlashcard('Lamp', '─É├¿n b├án'),
      _sampleFlashcard('Sofa', 'Ghß║┐ sofa'),
      _sampleFlashcard('Cup', 'Cß╗æc'),
      _sampleFlashcard('Plate', '─É─⌐a'),
      _sampleFlashcard('Spoon', 'Muß╗ùng'),
      _sampleFlashcard('Fork', 'N─⌐a'),
      _sampleFlashcard('Bowl', 'B├ít'),
      _sampleFlashcard('Mirror', 'G╞░╞íng'),
      _sampleFlashcard('Pillow', 'Gß╗æi'),
      _sampleFlashcard('Blanket', 'Ch─ân'),
      _sampleFlashcard('Door', 'Cß╗¡a'),
      _sampleFlashcard('Window', 'Cß╗¡a sß╗ò'),
    ],
    [
      _sampleFlashcard('Mountain', 'N├║i', image: 'assets/images/business.png'),
      _sampleFlashcard('River', 'S├┤ng', image: 'assets/images/business.png'),
      _sampleFlashcard('Forest', 'Rß╗½ng', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'Ocean',
        '─Éß║íi d╞░╞íng',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Sky',
        'Bß║ºu trß╗¥i',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Cloud',
        '─É├ím m├óy',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Rain', 'M╞░a', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'Sun',
        'Mß║╖t trß╗¥i',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Moon',
        'Mß║╖t tr─âng',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Star',
        'Ng├┤i sao',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Lake', 'Hß╗ô', image: 'assets/images/business.png'),
      _sampleFlashcard('Flower', 'Hoa', image: 'assets/images/business.png'),
      _sampleFlashcard('Tree', 'C├óy', image: 'assets/images/business.png'),
      _sampleFlashcard('Wind', 'Gi├│', image: 'assets/images/business.png'),
      _sampleFlashcard('Stone', '─É├í', image: 'assets/images/business.png'),
    ],
    [
      _sampleFlashcard(
        'Computer',
        'M├íy t├¡nh',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Laptop',
        'M├íy t├¡nh x├ích tay',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Phone',
        '─Éiß╗çn thoß║íi',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Tablet',
        'M├íy t├¡nh bß║úng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Keyboard',
        'B├án ph├¡m',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Mouse',
        'Chuß╗Öt m├íy t├¡nh',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Screen',
        'M├án h├¼nh',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Printer', 'M├íy in', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Camera',
        'M├íy ß║únh',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Robot', 'R├┤ bß╗æt', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Internet',
        'Mß║íng internet',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Software',
        'Phß║ºn mß╗üm',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Hardware',
        'Phß║ºn cß╗⌐ng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Server',
        'M├íy chß╗º',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Application',
        'ß╗¿ng dß╗Ñng',
        image: 'assets/images/toeic.png',
      ),
    ],
    [
      _sampleFlashcard('Apple', 'Quß║ú t├ío'),
      _sampleFlashcard('Banana', 'Quß║ú chuß╗æi'),
      _sampleFlashcard('Orange', 'Quß║ú cam'),
      _sampleFlashcard('Bread', 'B├ính m├¼'),
      _sampleFlashcard('Rice', 'C╞ím'),
      _sampleFlashcard('Noodle', 'M├¼'),
      _sampleFlashcard('Soup', 'S├║p'),
      _sampleFlashcard('Meat', 'Thß╗ït'),
      _sampleFlashcard('Fish', 'C├í'),
      _sampleFlashcard('Egg', 'Trß╗⌐ng'),
      _sampleFlashcard('Milk', 'Sß╗»a'),
      _sampleFlashcard('Cheese', 'Ph├┤ mai'),
      _sampleFlashcard('Sugar', '─É╞░ß╗¥ng'),
      _sampleFlashcard('Salt', 'Muß╗æi'),
      _sampleFlashcard('Butter', 'B╞í'),
    ],
    [
      _sampleFlashcard('Cat', 'M├¿o', image: 'assets/images/business.png'),
      _sampleFlashcard('Dog', 'Ch├│', image: 'assets/images/business.png'),
      _sampleFlashcard('Bird', 'Chim', image: 'assets/images/business.png'),
      _sampleFlashcard('Rabbit', 'Thß╗Å', image: 'assets/images/business.png'),
      _sampleFlashcard('Tiger', 'Hß╗ò', image: 'assets/images/business.png'),
      _sampleFlashcard('Lion', 'S╞░ tß╗¡', image: 'assets/images/business.png'),
      _sampleFlashcard('Elephant', 'Voi', image: 'assets/images/business.png'),
      _sampleFlashcard('Monkey', 'Khß╗ë', image: 'assets/images/business.png'),
      _sampleFlashcard('Horse', 'Ngß╗▒a', image: 'assets/images/business.png'),
      _sampleFlashcard('Cow', 'B├▓', image: 'assets/images/business.png'),
      _sampleFlashcard('Pig', 'Heo', image: 'assets/images/business.png'),
      _sampleFlashcard('Sheep', 'Cß╗½u', image: 'assets/images/business.png'),
      _sampleFlashcard('Duck', 'Vß╗ït', image: 'assets/images/business.png'),
      _sampleFlashcard('Chicken', 'G├á', image: 'assets/images/business.png'),
      _sampleFlashcard(
        'Butterfly',
        'B╞░╞ím b╞░ß╗¢m',
        image: 'assets/images/business.png',
      ),
    ],
    [
      _sampleFlashcard('Car', '├ö t├┤', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Bus', 'Xe bu├╜t', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Train', 'T├áu hß╗Åa', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Plane', 'M├íy bay', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Bike', 'Xe ─æß║íp', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Motorbike',
        'Xe m├íy',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Truck', 'Xe tß║úi', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Taxi', 'Xe taxi', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Ship', 'T├áu thß╗ºy', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Boat', 'Thuyß╗ün', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Helicopter',
        'Trß╗▒c th─âng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Subway',
        'T├áu ─æiß╗çn ngß║ºm',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Scooter',
        'Xe tay ga',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Bicycle',
        'Xe ─æß║íp',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Ambulance',
        'Xe cß╗⌐u th╞░╞íng',
        image: 'assets/images/toeic.png',
      ),
    ],
    [
      _sampleFlashcard('Run', 'Chß║íy'),
      _sampleFlashcard('Walk', '─Éi bß╗Ö'),
      _sampleFlashcard('Jump', 'Nhß║úy'),
      _sampleFlashcard('Swim', 'B╞íi'),
      _sampleFlashcard('Dance', 'Nhß║úy m├║a'),
      _sampleFlashcard('Sing', 'H├ít'),
      _sampleFlashcard('Read', '─Éß╗ìc'),
      _sampleFlashcard('Write', 'Viß║┐t'),
      _sampleFlashcard('Cook', 'Nß║Ñu ─ân'),
      _sampleFlashcard('Clean', 'Dß╗ìn dß║╣p'),
      _sampleFlashcard('Study', 'Hß╗ìc'),
      _sampleFlashcard('Work', 'L├ám viß╗çc'),
      _sampleFlashcard('Sleep', 'Ngß╗º'),
      _sampleFlashcard('Wake', 'Thß╗⌐c dß║¡y'),
      _sampleFlashcard('Play', 'Ch╞íi'),
    ],
    [
      _sampleFlashcard(
        'Blue',
        'M├áu xanh d╞░╞íng',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Red',
        'M├áu ─æß╗Å',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Green',
        'M├áu xanh l├í',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Yellow',
        'M├áu v├áng',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Black',
        'M├áu ─æen',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'White',
        'M├áu trß║»ng',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Orange',
        'M├áu cam',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Purple',
        'M├áu t├¡m',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Pink',
        'M├áu hß╗ông',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Brown',
        'M├áu n├óu',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Gray',
        'M├áu x├ím',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Gold',
        'M├áu v├áng kim',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Silver',
        'M├áu bß║íc',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard(
        'Violet',
        'M├áu t├¡m nhß║ít',
        image: 'assets/images/business.png',
      ),
      _sampleFlashcard('Beige', 'M├áu be', image: 'assets/images/business.png'),
    ],
    [
      _sampleFlashcard('House', 'Nh├á', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Room', 'Ph├▓ng', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Kitchen',
        'Nh├á bß║┐p',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Bathroom',
        'Ph├▓ng tß║»m',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Garden',
        'Khu v╞░ß╗¥n',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Street',
        '─É╞░ß╗¥ng phß╗æ',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'City',
        'Th├ánh phß╗æ',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Village',
        'Ng├┤i l├áng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'School',
        'Tr╞░ß╗¥ng hß╗ìc',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Hospital',
        'Bß╗çnh viß╗çn',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Office',
        'V─ân ph├▓ng',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Market', 'Chß╗ú', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Park', 'C├┤ng vi├¬n', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Bridge',
        'C├óy cß║ºu',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Library',
        'Th╞░ viß╗çn',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard('Large', 'Lß╗¢n', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Small', 'Nhß╗Å', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Big', 'To', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Near', 'Gß║ºn', image: 'assets/images/toeic.png'),
      _sampleFlashcard('Far', 'Xa', image: 'assets/images/toeic.png'),
      _sampleFlashcard(
        'Inside',
        'B├¬n trong',
        image: 'assets/images/toeic.png',
      ),
      _sampleFlashcard(
        'Outside',
        'B├¬n ngo├ái',
        image: 'assets/images/toeic.png',
      ),
    ],
    [
      _sampleFlashcard('Hour', 'Giß╗¥'),
      _sampleFlashcard('Minute', 'Ph├║t'),
      _sampleFlashcard('Second', 'Gi├óy'),
      _sampleFlashcard('Day', 'Ng├áy'),
      _sampleFlashcard('Week', 'Tuß║ºn'),
      _sampleFlashcard('Month', 'Th├íng'),
      _sampleFlashcard('Year', 'N─âm'),
      _sampleFlashcard('Morning', 'Buß╗òi s├íng'),
      _sampleFlashcard('Afternoon', 'Buß╗òi chiß╗üu'),
      _sampleFlashcard('Evening', 'Buß╗òi tß╗æi'),
      _sampleFlashcard('Night', 'Ban ─æ├¬m'),
      _sampleFlashcard('Today', 'H├┤m nay'),
      _sampleFlashcard('Yesterday', 'H├┤m qua'),
      _sampleFlashcard('Tomorrow', 'Ng├áy mai'),
      _sampleFlashcard('Calendar', 'Lß╗ïch'),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82);
    _initTts();
    _loadAutoPlayPronunciationSetting();
    _ensureVocabularyCount();
    _repository.watchCards();
    _loadPostponedWordsForTopic(_currentDisplayTopic());
  }

  Future<void> _loadAutoPlayPronunciationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final persistedValue = prefs.getBool(_autoPlaySettingKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _autoPlayPronunciationEnabled = persistedValue ?? true;
      _lastAutoSpokenCardKey = null;
    });

    if (!(_autoPlayPronunciationEnabled)) {
      await _tts.stop();
    }
  }

  String _currentDisplayTopic() {
    return widget.selectedTopic ?? deckNames[selectedDeck];
  }

  String _postponedStorageKey(String topic) {
    return '$_postponedWordsStoragePrefix::${topic.trim()}';
  }

  Future<void> _loadPostponedWordsForTopic(String topic) async {
    final normalizedTopic = topic.trim();
    if (normalizedTopic.isEmpty || _loadingPostponedWords) {
      return;
    }

    _loadingPostponedWords = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved =
          prefs.getStringList(_postponedStorageKey(normalizedTopic)) ??
          const <String>[];
      final cleaned = <String>[];
      for (final key in saved) {
        final normalizedKey = key.trim().toLowerCase();
        if (normalizedKey.isEmpty) {
          continue;
        }
        final isKnown = _repository.isKnown(
          normalizedKey,
          topic: normalizedTopic,
        );
        if (!isKnown && !cleaned.contains(normalizedKey)) {
          cleaned.add(normalizedKey);
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _postponedWordKeys
          ..clear()
          ..addAll(cleaned);
        _loadedPostponedTopic = normalizedTopic;
      });

      await prefs.setStringList(_postponedStorageKey(normalizedTopic), cleaned);
    } catch (_) {
      // Keep practice usable even if local storage fails.
    } finally {
      _loadingPostponedWords = false;
    }
  }

  Future<void> _persistPostponedWordsForTopic(String topic) async {
    final normalizedTopic = topic.trim();
    if (normalizedTopic.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _postponedStorageKey(normalizedTopic),
        List<String>.from(_postponedWordKeys),
      );
    } catch (_) {
      // Ignore persistence errors to avoid blocking user actions.
    }
  }

  void _ensureVocabularyCount() {
    for (final topic in deckNames) {
      final sourceDeckIndex = _sampleDeckIndexByTopic[topic] ?? 0;
      if (sourceDeckIndex < 0 || sourceDeckIndex >= allFlashcards.length) {
        continue;
      }
      final cards = allFlashcards[sourceDeckIndex];
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

  void _scheduleAutoSpeakCurrentCard(Flashcard? flashcard) {
    if (!_autoPlayPronunciationEnabled || flashcard == null) {
      return;
    }

    final autoSpeakKey =
        '${_isPracticeMode ? 'practice' : 'normal'}::${flashcard.word.trim().toLowerCase()}';
    if (_lastAutoSpokenCardKey == autoSpeakKey) {
      return;
    }
    _lastAutoSpokenCardKey = autoSpeakKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_autoPlayPronunciationEnabled) {
        return;
      }
      _speakWord(flashcard.word);
    });
  }

  void _closeWithPracticeResult(BuildContext context) {
    final practiced = _isPracticeMode && _practiceStartedAt != null;
    final durationSeconds = practiced
        ? DateTime.now().difference(_practiceStartedAt!).inSeconds
        : 0;

    Navigator.of(context).pop({
      'practiced': practiced,
      'practiceDurationSeconds': durationSeconds < 0 ? 0 : durationSeconds,
    });
  }

  List<Flashcard> _orderedPracticeFlashcards(
    List<Flashcard> cards,
    String topic,
  ) {
    final postponed = <Flashcard>[];
    final normal = <Flashcard>[];
    final known = <Flashcard>[];

    for (final card in cards) {
      final key = card.word.trim().toLowerCase();
      final isKnown =
          _repository.isKnown(key, topic: topic) ||
          _locallyKnownWordKeys.contains(key);
      final isPostponed =
          _postponedWordKeys.contains(key) || _recentlyPostponedWordKey == key;

      if (isKnown) {
        known.add(card);
      } else if (isPostponed) {
        postponed.add(card);
      } else {
        normal.add(card);
      }
    }

    postponed.sort((a, b) {
      final aIndex = _postponedWordKeys.indexOf(a.word.trim().toLowerCase());
      final bIndex = _postponedWordKeys.indexOf(b.word.trim().toLowerCase());
      return aIndex.compareTo(bIndex);
    });

    return [...postponed, ...normal, ...known];
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
          title: const Text('X├íc nhß║¡n x├│a ß║únh'),
          content: const Text(
            'Bß║ín c├│ chß║»c muß╗æn x├│a ß║únh minh hß╗ìa n├áy kh├┤ng?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hß╗ºy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('X├│a'),
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
        await _showOptionNotice(
          title: 'Kh├┤ng thß╗â chß╗ìn ß║únh',
          message: '$error',
        );
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
                    'T├╣y chß╗ìn cho tß╗½ "${card.word}"',
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
                                  errorBuilder: (_, __, ___) => Icon(
                                    _iconForTopic(displayTopic),
                                    color: const Color(0xFF0A5DB6),
                                    size: 34,
                                  ),
                                )
                              : Icon(
                                  _iconForTopic(displayTopic),
                                  color: const Color(0xFF0A5DB6),
                                  size: 34,
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
                              label: const Text('Chß╗Ñp ß║únh'),
                            ),
                            OutlinedButton.icon(
                              onPressed: isPickingImage
                                  ? null
                                  : () => pickImage(
                                      ImageSource.gallery,
                                      setModalState,
                                    ),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Chß╗ìn ß║únh'),
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
                                label: const Text('X├│a ß║únh'),
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
                      labelText: 'V├¡ dß╗Ñ ─æß║╖t c├óu vß╗¢i tß╗½ ${card.word}',
                      hintText: 'V├¡ dß╗Ñ phß║úi chß╗⌐a tß╗½ ${card.word}',
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
                        child: const Text('Hß╗ºy'),
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
                                    title: 'V├¡ dß╗Ñ ch╞░a hß╗úp lß╗ç',
                                    message:
                                        'C├óu v├¡ dß╗Ñ phß║úi chß╗⌐a tß╗½ "${card.word}".',
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
                                    title: 'L╞░u thß║Ñt bß║íi',
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
                        child: const Text('L╞░u t├╣y chß╗ìn'),
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
          title: 'Th├ánh c├┤ng',
          message: '─É├ú cß║¡p nhß║¡t tß╗½ vß╗▒ng.',
        );
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    exampleController.dispose();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine which topic to display
    final displayTopic = widget.selectedTopic ?? deckNames[selectedDeck];
    final topicIndex = _sampleDeckIndexByTopic[displayTopic] ?? 0;

    if (_loadedPostponedTopic != displayTopic && !_loadingPostponedWords) {
      _loadPostponedWordsForTopic(displayTopic);
    }

    return WillPopScope(
      onWillPop: () async {
        _closeWithPracticeResult(context);
        return false;
      },
      child: Scaffold(
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
                      meaning: _displayMeaning(
                        card.word,
                        card.meaning,
                        topic: displayTopic,
                      ),
                      example: _exampleForDisplay(card.word, card.example),
                      topic: card.topic,
                      imageBytes: card.imageBytes,
                    ),
                  )
                  .toList();

              final sampleCards =
                  topicIndex >= 0 && topicIndex < allFlashcards.length
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
                    meaning: _displayMeaning(
                      sample.word,
                      sample.meaning,
                      topic: displayTopic,
                    ),
                    example: _exampleForDisplay(sample.word, sample.example),
                    topic: displayTopic,
                    imageBytes: sample.imageBytes,
                  );
                }
              }

              final trackedFlashcards = widget.showOnlyTrackedWords
                  ? mergedFlashcards.where((card) {
                      final key = card.word.trim().toLowerCase();
                      final isKnown = _repository.isKnown(
                        key,
                        topic: displayTopic,
                      );
                      final isStudying =
                          savedCardsByWord.containsKey(key) ||
                          _postponedWordKeys.contains(key);
                      return isKnown || isStudying;
                    }).toList()
                  : mergedFlashcards;

              final flashcards = _isPracticeMode
                  ? _orderedPracticeFlashcards(trackedFlashcards, displayTopic)
                  : trackedFlashcards;
              final safeIndex = flashcards.isEmpty
                  ? 0
                  : (_isPracticeMode
                        ? 0
                        : _currentCardIndex % flashcards.length);
              final currentFlashcard = flashcards.isEmpty
                  ? null
                  : flashcards[safeIndex];
              final currentWordKey = currentFlashcard?.word
                  .trim()
                  .toLowerCase();
              _scheduleAutoSpeakCurrentCard(currentFlashcard);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, size: 28),
                          onPressed: () => _closeWithPracticeResult(context),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isPracticeMode ? 'Luyện tập' : displayTopic,
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
                                  'Ch╞░a c├│ tß╗½ n├áo trong bß╗Ö n├áy',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'H├úy th├¬m tß╗½ mß╗¢i tß╗½ mß╗Ñc Tß╗½ ─æiß╗ân',
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
                              final carouselHeight =
                                  (constraints.maxHeight - 220).clamp(
                                    280.0,
                                    500.0,
                                  );
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
                                    child: _isPracticeMode
                                        ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            child: Stack(
                                              alignment: Alignment.topCenter,
                                              children: List.generate(3, (
                                                layer,
                                              ) {
                                                final cardIndex =
                                                    (safeIndex + layer) %
                                                    flashcards.length;
                                                final card =
                                                    flashcards[cardIndex];
                                                final wordKey = card.word
                                                    .trim()
                                                    .toLowerCase();
                                                final isKnown =
                                                    _repository.isKnown(
                                                      wordKey,
                                                      topic: displayTopic,
                                                    ) ||
                                                    _locallyKnownWordKeys
                                                        .contains(wordKey) ||
                                                    _recentlyMarkedKnownWordKey ==
                                                        wordKey;
                                                final isPostponed =
                                                    _postponedWordKeys.contains(
                                                      wordKey,
                                                    ) ||
                                                    _recentlyPostponedWordKey ==
                                                        wordKey;
                                                final topOffset = (layer * 14.0)
                                                    .clamp(0.0, 28.0);
                                                final leftInset = (layer * 8.0)
                                                    .clamp(0.0, 16.0);
                                                final rightInset =
                                                    (layer * 24.0).clamp(
                                                      0.0,
                                                      48.0,
                                                    );

                                                return Positioned(
                                                  top: topOffset,
                                                  left: leftInset,
                                                  right: rightInset,
                                                  child: IgnorePointer(
                                                    ignoring: layer != 0,
                                                    child: Opacity(
                                                      opacity: layer == 0
                                                          ? 1.0
                                                          : (layer == 1
                                                                ? 0.92
                                                                : 0.86),
                                                      child: FlipCard(
                                                        key: ValueKey(
                                                          'stack-card-$cardIndex-${card.word}',
                                                        ),
                                                        direction: FlipDirection
                                                            .HORIZONTAL,
                                                        front: FlashcardFront(
                                                          flashcard: card,
                                                          isKnown: isKnown,
                                                          isPostponed:
                                                              isPostponed,
                                                          onSpeak: () =>
                                                              _speakWord(
                                                                card.word,
                                                              ),
                                                          width:
                                                              double.infinity,
                                                          height: cardHeight,
                                                        ),
                                                        back: FlashcardBack(
                                                          flashcard: card,
                                                          isKnown: isKnown,
                                                          isPostponed:
                                                              isPostponed,
                                                          onSpeak: () =>
                                                              _speakWord(
                                                                card.word,
                                                              ),
                                                          width:
                                                              double.infinity,
                                                          height: cardHeight,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).reversed.toList(),
                                            ),
                                          )
                                        : PageView.builder(
                                            controller: _pageController,
                                            padEnds: true,
                                            itemCount: flashcards.length,
                                            onPageChanged: (index) {
                                              if (_currentCardIndex != index) {
                                                setState(() {
                                                  _currentCardIndex = index;
                                                });
                                              }
                                            },
                                            itemBuilder: (context, index) {
                                              final card = flashcards[index];
                                              final wordKey = card.word
                                                  .trim()
                                                  .toLowerCase();
                                              final isKnown =
                                                  _repository.isKnown(
                                                    wordKey,
                                                    topic: displayTopic,
                                                  ) ||
                                                  _locallyKnownWordKeys
                                                      .contains(wordKey) ||
                                                  _recentlyMarkedKnownWordKey ==
                                                      wordKey;
                                              final isPostponed =
                                                  _postponedWordKeys.contains(
                                                    wordKey,
                                                  ) ||
                                                  _recentlyPostponedWordKey ==
                                                      wordKey;

                                              return AnimatedBuilder(
                                                animation: _pageController,
                                                builder: (context, child) {
                                                  var page = _currentCardIndex
                                                      .toDouble();
                                                  if (_pageController
                                                      .hasClients) {
                                                    page =
                                                        _pageController.page ??
                                                        _currentCardIndex
                                                            .toDouble();
                                                  }

                                                  final distance =
                                                      (page - index)
                                                          .abs()
                                                          .clamp(0.0, 1.0);
                                                  final scale =
                                                      1.0 - (distance * 0.1);
                                                  final opacity =
                                                      1.0 - (distance * 0.25);
                                                  final verticalOffset =
                                                      distance * 6.0;

                                                  return Opacity(
                                                    opacity: opacity.clamp(
                                                      0.75,
                                                      1.0,
                                                    ),
                                                    child: Transform.translate(
                                                      offset: Offset(
                                                        0,
                                                        verticalOffset,
                                                      ),
                                                      child: Transform.scale(
                                                        scale: scale.clamp(
                                                          0.9,
                                                          1.0,
                                                        ),
                                                        child: child,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 10,
                                                      ),
                                                  child: Center(
                                                    child: FlipCard(
                                                      key: ValueKey(
                                                        'slider-card-$index-${card.word}',
                                                      ),
                                                      direction: FlipDirection
                                                          .HORIZONTAL,
                                                      front: FlashcardFront(
                                                        flashcard: card,
                                                        isKnown: isKnown,
                                                        isPostponed:
                                                            isPostponed,
                                                        onSpeak: () =>
                                                            _speakWord(
                                                              card.word,
                                                            ),
                                                        width: double.infinity,
                                                        height: cardHeight,
                                                      ),
                                                      back: FlashcardBack(
                                                        flashcard: card,
                                                        isKnown: isKnown,
                                                        isPostponed:
                                                            isPostponed,
                                                        onSpeak: () =>
                                                            _speakWord(
                                                              card.word,
                                                            ),
                                                        width: double.infinity,
                                                        height: cardHeight,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0,
                                    ),
                                    child: _isPracticeMode
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        const Color(0xFF0A5DB6),
                                                    side: const BorderSide(
                                                      color: Color(0xFF0A5DB6),
                                                      width: 1.5,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                  ),
                                                  onPressed:
                                                      currentFlashcard == null
                                                      ? null
                                                      : () async {
                                                          setState(() {
                                                            _recentlyMarkedKnownWordKey =
                                                                null;
                                                            _recentlyPostponedWordKey =
                                                                currentWordKey;
                                                            if (currentWordKey !=
                                                                null) {
                                                              _postponedWordKeys
                                                                  .remove(
                                                                    currentWordKey,
                                                                  );
                                                              _postponedWordKeys
                                                                  .insert(
                                                                    0,
                                                                    currentWordKey,
                                                                  );
                                                            }
                                                          });
                                                          _persistPostponedWordsForTopic(
                                                            displayTopic,
                                                          );

                                                          await Future<
                                                            void
                                                          >.delayed(
                                                            const Duration(
                                                              milliseconds: 220,
                                                            ),
                                                          );
                                                          if (!mounted) {
                                                            return;
                                                          }

                                                          setState(() {
                                                            _recentlyPostponedWordKey =
                                                                null;
                                                          });
                                                        },
                                                  child: const Text('Đang học'),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF0A5DB6),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                  ),
                                                  onPressed:
                                                      currentWordKey == null
                                                      ? null
                                                      : () async {
                                                          setState(() {
                                                            _recentlyPostponedWordKey =
                                                                null;
                                                            _recentlyMarkedKnownWordKey =
                                                                currentWordKey;
                                                          });

                                                          await Future<
                                                            void
                                                          >.delayed(
                                                            const Duration(
                                                              milliseconds: 320,
                                                            ),
                                                          );
                                                          if (!mounted) {
                                                            return;
                                                          }

                                                          setState(() {
                                                            if (currentWordKey !=
                                                                null) {
                                                              _locallyKnownWordKeys
                                                                  .add(
                                                                    currentWordKey,
                                                                  );
                                                            }
                                                            _repository.markKnown(
                                                              currentWordKey,
                                                              topic:
                                                                  displayTopic,
                                                            );
                                                            _postponedWordKeys
                                                                .remove(
                                                                  currentWordKey,
                                                                );
                                                            _currentCardIndex =
                                                                0;
                                                            _recentlyMarkedKnownWordKey =
                                                                null;
                                                          });
                                                          _persistPostponedWordsForTopic(
                                                            displayTopic,
                                                          );
                                                        },
                                                  child: const Text(
                                                    'Đã nhớ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : (widget.showOnlyTrackedWords
                                              ? const SizedBox.shrink()
                                              : SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                            0xFF0A5DB6,
                                                          ),
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                    ),
                                                    onPressed:
                                                        currentFlashcard == null
                                                        ? null
                                                        : () {
                                                            setState(() {
                                                              _isPracticeMode =
                                                                  true;
                                                              _practiceStartedAt ??=
                                                                  DateTime.now();
                                                              _recentlyPostponedWordKey =
                                                                  null;
                                                              _recentlyMarkedKnownWordKey =
                                                                  null;
                                                            });
                                                          },
                                                    child: const Text(
                                                      'Luyện tập',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                )),
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
    meaning: _displayMeaning(word, meaning),
    example: 'V├¡ dß╗Ñ: $word',
  );
}

const Map<String, String> _vietnameseMeaningByWord = {
  'chair': 'Ghế',
  'table': 'Bàn',
  'bed': 'Giường',
  'lamp': 'Đèn bàn',
  'sofa': 'Ghế sofa',
  'cup': 'Cốc',
  'plate': 'Đĩa',
  'spoon': 'Muỗng',
  'fork': 'Nĩa',
  'bowl': 'Bát',
  'mirror': 'Gương',
  'pillow': 'Gối',
  'blanket': 'Chăn',
  'door': 'Cửa',
  'window': 'Cửa sổ',
  'mountain': 'Núi',
  'river': 'Sông',
  'forest': 'Rừng',
  'ocean': 'Đại dương',
  'sky': 'Bầu trời',
  'cloud': 'Đám mây',
  'rain': 'Mưa',
  'sun': 'Mặt trời',
  'moon': 'Mặt trăng',
  'star': 'Ngôi sao',
  'lake': 'Hồ',
  'flower': 'Hoa',
  'tree': 'Cây',
  'wind': 'Gió',
  'stone': 'Đá',
  'computer': 'Máy tính',
  'laptop': 'Máy tính xách tay',
  'phone': 'Điện thoại',
  'tablet': 'Máy tính bảng',
  'keyboard': 'Bàn phím',
  'mouse': 'Chuột máy tính',
  'screen': 'Màn hình',
  'printer': 'Máy in',
  'camera': 'Máy ảnh',
  'robot': 'Rô bốt',
  'internet': 'Mạng internet',
  'software': 'Phần mềm',
  'hardware': 'Phần cứng',
  'server': 'Máy chủ',
  'application': 'Ứng dụng',
  'apple': 'Quả táo',
  'banana': 'Quả chuối',
  'orange': 'Quả cam',
  'bread': 'Bánh mì',
  'rice': 'Cơm',
  'noodle': 'Mì',
  'soup': 'Súp',
  'meat': 'Thịt',
  'fish': 'Cá',
  'egg': 'Trứng',
  'milk': 'Sữa',
  'cheese': 'Phô mai',
  'sugar': 'Đường',
  'salt': 'Muối',
  'butter': 'Bơ',
  'cat': 'Mèo',
  'dog': 'Chó',
  'bird': 'Chim',
  'rabbit': 'Thỏ',
  'tiger': 'Hổ',
  'lion': 'Sư tử',
  'elephant': 'Voi',
  'monkey': 'Khỉ',
  'horse': 'Ngựa',
  'cow': 'Bò',
  'pig': 'Heo',
  'sheep': 'Cừu',
  'duck': 'Vịt',
  'chicken': 'Gà',
  'butterfly': 'Bướm',
  'car': 'Ô tô',
  'bus': 'Xe buýt',
  'train': 'Tàu hỏa',
  'plane': 'Máy bay',
  'bike': 'Xe đạp',
  'motorbike': 'Xe máy',
  'truck': 'Xe tải',
  'taxi': 'Xe taxi',
  'ship': 'Tàu thủy',
  'boat': 'Thuyền',
  'helicopter': 'Trực thăng',
  'subway': 'Tàu điện ngầm',
  'scooter': 'Xe tay ga',
  'bicycle': 'Xe đạp',
  'ambulance': 'Xe cứu thương',
  'house': 'Nhà',
  'room': 'Phòng',
  'kitchen': 'Nhà bếp',
  'bathroom': 'Phòng tắm',
  'garden': 'Khu vườn',
  'street': 'Đường phố',
  'city': 'Thành phố',
  'village': 'Ngôi làng',
  'school': 'Trường học',
  'hospital': 'Bệnh viện',
  'office': 'Văn phòng',
  'market': 'Chợ',
  'park': 'Công viên',
  'bridge': 'Cây cầu',
  'library': 'Thư viện',
  'large': 'Lớn',
  'small': 'Nhỏ',
  'big': 'To',
  'near': 'Gần',
  'far': 'Xa',
  'inside': 'Bên trong',
  'outside': 'Bên ngoài',
  'open': 'Mở',
  'close': 'Đóng',
  'start': 'Bắt đầu',
  'finish': 'Kết thúc',
  'easy': 'Dễ',
  'difficult': 'Khó',
  'fast': 'Nhanh',
  'slow': 'Chậm',
  'hot': 'Nóng',
  'cold': 'Lạnh',
  'happy': 'Vui',
  'sad': 'Buồn',
  'strong': 'Mạnh',
  'weak': 'Yếu',
  'clean': 'Sạch',
  'dirty': 'Bẩn',
  'safe': 'An toàn',
  'dangerous': 'Nguy hiểm',
  'important': 'Quan trọng',
  'special': 'Đặc biệt',
  'simple': 'Đơn giản',
  'complex': 'Phức tạp',
  'early': 'Sớm',
  'late': 'Muộn',
  'fresh': 'Tươi',
  'dry': 'Khô',
  'wet': 'Ướt',
  'quiet': 'Yên tĩnh',
  'noisy': 'Ồn ào',
  'modern': 'Hiện đại',
  'classic': 'Cổ điển',
  'public': 'Công cộng',
  'private': 'Riêng tư',
  'available': 'Có sẵn',
  'missing': 'Thiếu',
  'correct': 'Đúng',
  'wrong': 'Sai',
  'helpful': 'Hữu ích',
  'useful': 'Có ích',
  'popular': 'Phổ biến',
  'wardrobe': 'Tủ quần áo',
  'drawer': 'Ngăn kéo',
  'kettle': 'Ấm đun nước',
  'microwave': 'Lò vi sóng',
  'refrigerator': 'Tủ lạnh',
  'stove': 'Bếp',
  'pan': 'Chảo',
  'pot': 'Nồi',
  'towel': 'Khăn tắm',
  'toothbrush': 'Bàn chải đánh răng',
  'shampoo': 'Dầu gội',
  'soap': 'Xà phòng',
  'valley': 'Thung lũng',
  'desert': 'Sa mạc',
  'island': 'Hòn đảo',
  'waterfall': 'Thác nước',
  'volcano': 'Núi lửa',
  'thunder': 'Sấm',
  'lightning': 'Tia chớp',
  'rainbow': 'Cầu vồng',
  'leaf': 'Lá cây',
  'branch': 'Cành cây',
  'soil': 'Đất',
  'sand': 'Cát',
  'code': 'Mã lập trình',
  'program': 'Chương trình',
  'database': 'Cơ sở dữ liệu',
  'network': 'Mạng',
  'password': 'Mật khẩu',
  'security': 'Bảo mật',
  'update': 'Cập nhật',
  'download': 'Tải xuống',
  'upload': 'Tải lên',
  'device': 'Thiết bị',
  'processor': 'Bộ xử lý',
  'vegetable': 'Rau củ',
  'fruit': 'Trái cây',
  'pork': 'Thịt heo',
  'beef': 'Thịt bò',
  'shrimp': 'Tôm',
  'crab': 'Cua',
  'juice': 'Nước ép',
  'tea': 'Trà',
  'coffee': 'Cà phê',
  'honey': 'Mật ong',
  'pepper': 'Tiêu',
  'bear': 'Gấu',
  'wolf': 'Sói',
  'fox': 'Cáo',
  'deer': 'Hươu',
  'goat': 'Dê',
  'donkey': 'Lừa',
  'eagle': 'Đại bàng',
  'parrot': 'Vẹt',
  'dolphin': 'Cá heo',
  'whale': 'Cá voi',
  'shark': 'Cá mập',
  'ant': 'Kiến',
  'van': 'Xe tải nhỏ',
  'tram': 'Xe điện',
  'ferry': 'Phà',
  'canoe': 'Ca nô',
  'yacht': 'Du thuyền',
  'skateboard': 'Ván trượt',
  'rollerblade': 'Giày trượt',
  'wheelchair': 'Xe lăn',
  'cart': 'Xe đẩy',
  'rocket': 'Tên lửa',
  'jet': 'Máy bay phản lực',
  'glider': 'Tàu lượn',
  'listen': 'Lắng nghe',
  'speak': 'Nói',
  'watch': 'Xem',
  'think': 'Suy nghĩ',
  'build': 'Xây dựng',
  'fix': 'Sửa chữa',
  'drive': 'Lái xe',
  'travel': 'Du lịch',
  'practice': 'Luyện tập',
  'exercise': 'Tập thể dục',
  'relax': 'Thư giãn',
  'celebrate': 'Ăn mừng',
  'turquoise': 'Màu xanh ngọc',
  'crimson': 'Màu đỏ thẫm',
  'navy': 'Màu xanh hải quân',
  'olive': 'Màu ô liu',
  'lavender': 'Màu oải hương',
  'maroon': 'Màu đỏ nâu',
  'coral': 'Màu san hô',
  'amber': 'Màu hổ phách',
  'ivory': 'Màu ngà',
  'mint': 'Màu xanh bạc hà',
  'peach': 'Màu đào',
  'teal': 'Màu xanh mòng két',
  'area': 'Khu vực',
  'zone': 'Vùng',
  'corner': 'Góc',
  'center': 'Trung tâm',
  'border': 'Biên giới',
  'front': 'Phía trước',
  'back': 'Phía sau',
  'left': 'Bên trái',
  'right': 'Bên phải',
  'above': 'Phía trên',
  'below': 'Phía dưới',
  'middle': 'Ở giữa',
  'clock': 'Đồng hồ',
  'date': 'Ngày',
  'schedule': 'Lịch trình',
  'deadline': 'Hạn chót',
  'moment': 'Khoảnh khắc',
  'period': 'Khoảng thời gian',
  'century': 'Thế kỷ',
  'decade': 'Thập kỷ',
  'season': 'Mùa',
  'spring': 'Mùa xuân',
  'summer': 'Mùa hè',
  'winter': 'Mùa đông',
  'run': 'Chạy',
  'walk': 'Đi bộ',
  'jump': 'Nhảy',
  'swim': 'Bơi',
  'dance': 'Nhảy múa',
  'sing': 'Hát',
  'read': 'Đọc',
  'write': 'Viết',
  'cook': 'Nấu ăn',
  'study': 'Học',
  'work': 'Làm việc',
  'sleep': 'Ngủ',
  'wake': 'Thức dậy',
  'play': 'Chơi',
  'blue': 'Màu xanh dương',
  'red': 'Màu đỏ',
  'green': 'Màu xanh lá',
  'yellow': 'Màu vàng',
  'black': 'Màu đen',
  'white': 'Màu trắng',
  'purple': 'Màu tím',
  'pink': 'Màu hồng',
  'brown': 'Màu nâu',
  'gray': 'Màu xám',
  'gold': 'Màu vàng kim',
  'silver': 'Màu bạc',
  'violet': 'Màu tím nhạt',
  'beige': 'Màu be',
  'hour': 'Giờ',
  'minute': 'Phút',
  'second': 'Giây',
  'day': 'Ngày',
  'week': 'Tuần',
  'month': 'Tháng',
  'year': 'Năm',
  'morning': 'Buổi sáng',
  'afternoon': 'Buổi chiều',
  'evening': 'Buổi tối',
  'night': 'Ban đêm',
  'today': 'Hôm nay',
  'yesterday': 'Hôm qua',
  'tomorrow': 'Ngày mai',
  'calendar': 'Lịch',
};

String _displayMeaning(String word, String fallbackMeaning, {String? topic}) {
  final key = word.trim().toLowerCase();
  final topicKey = topic?.trim() ?? '';

  if (key == 'chicken') {
    if (topicKey == 'Đồ ăn') {
      return 'Thịt gà';
    }
    if (topicKey == 'Động vật') {
      return 'Gà';
    }
  }

  if (key == 'orange') {
    if (topicKey == 'Đồ ăn') {
      return 'Quả cam';
    }
    if (topicKey == 'Màu sắc') {
      return 'Màu cam';
    }
  }

  if (key == 'clean' && topicKey == 'Học tập') {
    return 'Dọn dẹp';
  }

  final mappedMeaning = _vietnameseMeaningByWord[key];
  if (mappedMeaning != null && mappedMeaning.trim().isNotEmpty) {
    return mappedMeaning;
  }

  return _repairMojibakeText(fallbackMeaning);
}

String _repairMojibakeText(String input) {
  final text = input.trim();
  if (text.isEmpty) {
    return input;
  }

  final looksCorrupted =
      text.contains('├') ||
      text.contains('ß') ||
      text.contains('╞') ||
      text.contains('─') ||
      text.contains('║') ||
      text.contains('╗') ||
      text.contains('┐') ||
      text.contains('⌐');

  if (!looksCorrupted) {
    return input;
  }

  try {
    return utf8.decode(latin1.encode(text));
  } catch (_) {
    return input;
  }
}

String _resolveFlashcardImage({
  required String word,
  required String meaning,
  String? topic,
  String? imageUrl,
}) {
  final explicit = imageUrl?.trim() ?? '';
  if (explicit.isNotEmpty &&
      (explicit.startsWith('http://') ||
          explicit.startsWith('https://') ||
          explicit.startsWith('assets/'))) {
    return explicit;
  }

  return '';
}

IconData _iconForTopic(String topic) {
  switch (topic.trim()) {
    case 'Đồ điện tử':
      return Icons.electrical_services;
    case 'Đồ nội thất':
      return Icons.chair_alt;
    case 'Động vật':
    case 'Con vật':
      return Icons.pets;
    case 'Thiên nhiên':
      return Icons.nature;
    case 'Công nghệ':
      return Icons.memory;
    case 'Học tập':
      return Icons.school;
    case 'Đồ ăn':
      return Icons.restaurant;
    case 'Phương tiện':
      return Icons.directions_car;
    default:
      return Icons.auto_stories_rounded;
  }
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
  final bool isPostponed;
  final VoidCallback onSpeak;
  final double width;
  final double height;
  FlashcardFront({
    super.key,
    required this.flashcard,
    required this.isKnown,
    this.isPostponed = false,
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

    if (source.isEmpty) {
      return _fallbackIcon();
    }

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
      child: Icon(
        _iconForTopic(flashcard.topic),
        size: 58,
        color: const Color(0xFF0A5DB6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: isKnown
          ? const Color(0xFFE7F8ED)
          : (isPostponed ? const Color(0xFFFFF8D9) : null),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              flashcard.phonetic.trim().isEmpty
                  ? '/${flashcard.word.toLowerCase()}/'
                  : flashcard.phonetic,
              style: const TextStyle(fontSize: 20, color: Colors.blueGrey),
              textAlign: TextAlign.center,
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
  final bool isPostponed;
  final VoidCallback onSpeak;
  final double width;
  final double height;
  FlashcardBack({
    super.key,
    required this.flashcard,
    required this.isKnown,
    this.isPostponed = false,
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
    if (source.isEmpty) {
      return _fallbackIcon();
    }

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
      child: Icon(
        _iconForTopic(flashcard.topic),
        size: 58,
        color: const Color(0xFF0A5DB6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: isKnown
          ? const Color(0xFFE7F8ED)
          : (isPostponed ? const Color(0xFFFFF8D9) : null),
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
              textAlign: TextAlign.center,
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
          _errorText = 'Kh├┤ng t├¼m thß║Ñy camera tr├¬n thiß║┐t bß╗ï';
        });
        return;
      }

      _cameras = cameras;
      await _createController(cameras[_cameraIndex]);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Kh├┤ng thß╗â mß╗ƒ camera: $error';
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
        _errorText = 'Kh├┤ng thß╗â ─æß╗òi camera: $error';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kh├┤ng thß╗â chß╗Ñp ß║únh: $error')),
      );
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
        title: const Text('Chß╗Ñp ß║únh minh hß╗ìa'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
              tooltip: '─Éß╗òi camera',
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
                'Camera ch╞░a sß║╡n s├áng',
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
