class TopicClassifier {
  static const List<String> topics = [
    'Electronics',
    'Furniture',
    'Animals',
    'Nature',
    'Technology',
    'Learning',
    'Food',
    'Vehicles',
    'Household Items',
  ];

  static String normalizeTopic(String topic) {
    if (topic.contains('điện tử') || topic.contains('Ä‘iá»‡n tá»'))
      return 'Electronics';
    if (topic.contains('nội thất') || topic.contains('ná»™i tháº¥t'))
      return 'Furniture';
    if (topic.contains('Động vật') || topic.contains('Äá»™ng váºt'))
      return 'Animals';
    if (topic.contains('Thiên nhiên') || topic.contains('ThiÃªn nhiÃªn'))
      return 'Nature';
    if (topic.contains('Công nghệ') || topic.contains('CÃ´ng nghá»‡'))
      return 'Technology';
    if (topic.contains('Học tập') || topic.contains('Há»c táºp'))
      return 'Learning';
    if (topic.contains('Đồ ăn') || topic.contains('Äá»“ Äƒn')) return 'Food';
    if (topic.contains('Phương tiện') || topic.contains('PhÆ°Æ¡ng tiá»‡n'))
      return 'Vehicles';
    if (topic.contains('gia đình') || topic.contains('Household'))
      return 'Household Items';
    return topic;
  }

  static String getVietnameseTopic(String topic) {
    final norm = normalizeTopic(topic);
    switch (norm) {
      case 'Electronics':
        return 'Đồ điện tử';
      case 'Furniture':
        return 'Đồ nội thất';
      case 'Animals':
        return 'Động vật';
      case 'Nature':
        return 'Thiên nhiên';
      case 'Technology':
        return 'Công nghệ';
      case 'Learning':
        return 'Học tập';
      case 'Food':
        return 'Đồ ăn';
      case 'Vehicles':
        return 'Phương tiện';
      case 'Household Items':
        return 'Vật dụng gia đình';
      default:
        return norm;
    }
  }

  static const Map<String, List<String>> keywords = {
    'Electronics': [
      'phone',
      'tablet',
      'camera',
      'speaker',
      'headphone',
      'charger',
      'battery',
      'remote',
      'điện thoại',
      'máy tính bảng',
      'máy ảnh',
      'loa',
      'tai nghe',
      'bộ sạc',
      'pin',
      'điều khiển',
      'electronic',
      'device',
      'gadget',
    ],
    'Furniture': [
      'chair',
      'table',
      'bed',
      'lamp',
      'door',
      'window',
      'sofa',
      'cabinet',
      'ghế',
      'bàn',
      'giường',
      'đèn',
      'cửa',
      'tủ',
      'sofa',
    ],
    'Nature': [
      'tree',
      'flower',
      'mountain',
      'river',
      'sky',
      'sun',
      'moon',
      'cloud',
      'rain',
      'cây',
      'hoa',
      'núi',
      'sông',
      'trời',
      'mặt trời',
      'mặt trăng',
      'mây',
      'mưa',
      'forest',
      'ocean',
      'sea',
      'beach',
      'grass',
      'stone',
      'rock',
      'water',
      'rừng',
      'biển',
      'bãi biển',
      'cỏ',
      'đá',
    ],
    'Technology': [
      'computer',
      'phone',
      'laptop',
      'tablet',
      'robot',
      'camera',
      'screen',
      'keyboard',
      'máy tính',
      'điện thoại',
      'robot',
      'camera',
      'màn hình',
      'bàn phím',
      'chuột',
      'electric',
      'digital',
      'software',
      'app',
      'internet',
      'wifi',
      'server',
      'điện tử',
      'kỹ thuật số',
      'phần mềm',
    ],
    'Food': [
      'apple',
      'banana',
      'bread',
      'rice',
      'meat',
      'fish',
      'chicken',
      'egg',
      'milk',
      'táo',
      'chuối',
      'bánh',
      'cơm',
      'thịt',
      'cá',
      'gà',
      'trứng',
      'sữa',
      'orange',
      'lemon',
      'cheese',
      'sugar',
      'salt',
      'oil',
      'butter',
      'cam',
      'chanh',
      'phô mai',
      'đường',
      'muối',
      'dầu',
      'bơ',
    ],
    'Animals': [
      'cat',
      'dog',
      'bird',
      'fish',
      'lion',
      'tiger',
      'elephant',
      'monkey',
      'rabbit',
      'mèo',
      'chó',
      'chim',
      'cá',
      'sư tử',
      'hổ',
      'voi',
      'khỉ',
      'thỏ',
      'horse',
      'cow',
      'pig',
      'sheep',
      'snake',
      'insect',
      'butterfly',
      'spider',
      'ngựa',
      'bò',
      'lợn',
      'cừu',
      'rắn',
      'côn trùng',
      'bướm',
      'nhện',
    ],
    'Vehicles': [
      'car',
      'bus',
      'train',
      'plane',
      'bike',
      'motorcycle',
      'truck',
      'taxi',
      'boat',
      'ô tô',
      'xe buýt',
      'tàu',
      'máy bay',
      'xe đạp',
      'xe máy',
      'xe tải',
      'taxi',
      'thuyền',
      'helicopter',
      'ship',
      'submarine',
      'bicycle',
      'vehicle',
      'transport',
      'trực thăng',
      'tàu',
      'tàu ngầm',
      'xe cộ',
      'vận tải',
    ],
    'Learning': [
      'study',
      'learn',
      'read',
      'write',
      'book',
      'notebook',
      'pen',
      'pencil',
      'class',
      'classroom',
      'teacher',
      'student',
      'school',
      'lesson',
      'homework',
      'exam',
      'quiz',
      'học',
      'đọc',
      'viết',
      'sách',
      'vở',
      'bút',
      'lớp học',
      'giáo viên',
      'học sinh',
      'trường',
      'bài học',
      'bài tập',
      'kiểm tra',
      'kỳ thi',
    ],
    'Household Items': [
      'pot',
      'pan',
      'kitchen',
      'utensil',
      'plate',
      'cup',
      'spoon',
      'fork',
      'nồi',
      'chảo',
      'đĩa',
      'cốc',
      'muỗng',
      'nhà bếp',
      'đồ dùng',
    ],
  };

  static String classifyWord(String word, String meaning) {
    final lowerWord = word.toLowerCase();
    final lowerMeaning = meaning.toLowerCase();
    final combined = '$lowerWord $lowerMeaning';

    final scores = <String, int>{};
    for (final topic in topics) {
      scores[topic] = 0;
    }

    for (final topic in topics) {
      final topicKeywords = keywords[topic] ?? [];
      for (final keyword in topicKeywords) {
        if (combined.contains(keyword.toLowerCase())) {
          scores[topic] = (scores[topic] ?? 0) + 1;
        }
      }
    }

    String bestTopic = topics[0];
    int maxScore = 0;

    for (final entry in scores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        bestTopic = entry.key;
      }
    }

    return maxScore > 0 ? bestTopic : topics[0];
  }

  static int getTopicIndex(String topicName) {
    final norm = normalizeTopic(topicName);
    return topics.indexOf(norm);
  }

  static String getTopicName(int index) {
    return topics.isNotEmpty && index >= 0 && index < topics.length
        ? topics[index]
        : topics[0];
  }
}
