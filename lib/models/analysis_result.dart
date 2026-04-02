class AnalysisResult {
  final String topic;
  final String word;
  final String phonetic;
  final String vietnameseMeaning;
  final String wordType;
  final String exampleSentence;
  final String pronunciationGuide;

  AnalysisResult({
    required this.topic,
    required this.word,
    required this.phonetic,
    required this.vietnameseMeaning,
    required this.wordType,
    required this.exampleSentence,
    required this.pronunciationGuide,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      topic: json['topic'] ?? json['category'] ?? 'General',
      word: json['word'] ?? '',
      phonetic: json['phonetic'] ?? '',
      vietnameseMeaning: json['vietnamese_meaning'] ?? '',
      wordType: json['word_type'] ?? '',
      exampleSentence: json['example_sentence'] ?? '',
      pronunciationGuide: json['pronunciation_guide'] ?? '',
    );
  }

  String get normalizedWord => word.trim().toLowerCase();
}
