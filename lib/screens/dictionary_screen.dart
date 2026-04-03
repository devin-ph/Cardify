import 'dart:ui';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/saved_card.dart';
import '../services/saved_cards_repository.dart';
import '../services/topic_classifier.dart';
import '../services/translation_service.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final SavedCardsRepository _repository = SavedCardsRepository.instance;
  late final TextEditingController _searchController;

  bool _exampleContainsWord(String word, String example) {
    final normalizedWord = word.trim().toLowerCase();
    if (normalizedWord.isEmpty) {
      return false;
    }
    final normalizedExample = example.trim().toLowerCase();
    if (normalizedExample.isEmpty) {
      return true;
    }

    final escapedWord = RegExp.escape(normalizedWord);
    final boundaryPattern = RegExp(
      '(^|[^a-z0-9])' + escapedWord + r'([^a-z0-9]|$)',
      caseSensitive: false,
    );
    return boundaryPattern.hasMatch(normalizedExample);
  }

  Future<bool> _confirmDeleteImageDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
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

  Future<void> _openEditCardSheet(SavedCard card) async {
    final exampleController = TextEditingController(text: card.example);
    Uint8List? selectedImageBytes = card.imageBytes;
    String? selectedImageUrl = card.imageUrl;
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
              builder: (_) => const _QuickCameraCaptureScreen(),
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

        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1440,
          imageQuality: 88,
        );
        if (image == null || !mounted) {
          return;
        }
        final bytes = await image.readAsBytes();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể chọn ảnh: $error')));
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
      builder: (sheetContext) {
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
                    'Chỉnh sửa từ ${card.word}',
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
                            : () => Navigator.of(sheetContext).pop(),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final sentence = exampleController.text.trim();
                                if (sentence.isNotEmpty &&
                                    !_exampleContainsWord(
                                      card.word,
                                      sentence,
                                    )) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Câu ví dụ phải chứa từ ${card.word}',
                                      ),
                                    ),
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
                                    topic: card.topic,
                                    phonetic: card.phonetic,
                                    example: sentence,
                                    imageBytes: selectedImageBytes,
                                    existingImageUrl: selectedImageUrl,
                                    removeImage: removeCurrentImage,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  saveSucceeded = true;
                                  Navigator.of(sheetContext).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã cập nhật từ vựng'),
                                    ),
                                  );
                                } catch (error) {
                                  if (!mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$error')),
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
                        child: const Text('Lưu thay đổi'),
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

    await Future<void>.delayed(const Duration(milliseconds: 250));
    exampleController.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _repository.watchCards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCardDetails(SavedCard card) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chi tiết từ',
      barrierColor: Colors.black45,
      pageBuilder: (context, _, __) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CardDetailImage(
                        imageUrl: card.imageUrl,
                        imageBytes: card.imageBytes,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        card.word,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.phonetic.isEmpty
                            ? 'Chưa có phiên âm'
                            : card.phonetic,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        card.meaning,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                      if (card.example.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            card.example,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _openEditCardSheet(card);
                            },
                            child: const Text('Chỉnh sửa'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Đóng'),
                          ),
                        ],
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
              child: Container(color: Colors.black.withValues(alpha: 0)),
            ),
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.75, end: 1.0).animate(curved),
                child: FadeTransition(opacity: anim1, child: child),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddWordSheet() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: _AddWordSheetContent(
            repository: _repository,
            onWordAdded: () {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Đã thêm từ mới')));
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ điển'),
        backgroundColor: Colors.blue[400],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Thêm từ mới',
            onPressed: _showAddWordSheet,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<SavedCard>>(
          valueListenable: _repository.cardsNotifier,
          builder: (context, cards, _) {
            if (cards.isEmpty) {
              return const _CenteredMessage(
                message: 'Chưa có từ nào được lưu',
                icon: Icons.menu_book_outlined,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final card = cards[index];
                return ListTile(
                  onTap: () => _openCardDetails(card),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: Colors.blue[50],
                  leading: _CardThumbnail(
                    imageUrl: card.imageUrl,
                    imageBytes: card.imageBytes,
                  ),
                  title: Text(
                    card.word,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(card.meaning),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CardThumbnail extends StatelessWidget {
  const _CardThumbnail({required this.imageUrl, required this.imageBytes});

  final String? imageUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : imageBytes != null
            ? DecorationImage(
                image: MemoryImage(imageBytes!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null && imageBytes == null
          ? const Icon(Icons.image, color: Colors.blueGrey)
          : null,
    );
  }
}

class _CardDetailImage extends StatelessWidget {
  const _CardDetailImage({required this.imageUrl, required this.imageBytes});

  final String? imageUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null && imageBytes == null) {
      return Container(
        width: 230,
        height: 230,
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.image, size: 120, color: Colors.blueGrey),
      );
    }

    if (imageUrl == null && imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          imageBytes!,
          width: 230,
          height: 230,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 230,
            height: 230,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.broken_image, color: Colors.blueGrey),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl!,
        height: 230,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 230,
          height: 230,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.broken_image, color: Colors.blueGrey),
        ),
      ),
    );
  }
}

class _AddWordSheetContent extends StatefulWidget {
  final SavedCardsRepository repository;
  final VoidCallback onWordAdded;

  const _AddWordSheetContent({
    required this.repository,
    required this.onWordAdded,
  });

  @override
  State<_AddWordSheetContent> createState() => _AddWordSheetContentState();
}

class _AddWordSheetContentState extends State<_AddWordSheetContent> {
  late TextEditingController wordController;
  late TextEditingController meaningController;
  late TextEditingController phoneticController;
  late TextEditingController exampleController;
  late TextEditingController topicController;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  bool isLoading = false;
  bool isTranslatingExample = false;
  bool isPickingImage = false;

  Future<bool> _confirmDeleteImageDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
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

  @override
  void initState() {
    super.initState();
    wordController = TextEditingController();
    wordController.value = const TextEditingValue(text: '');

    meaningController = TextEditingController();
    meaningController.value = const TextEditingValue(text: '');

    phoneticController = TextEditingController();
    phoneticController.value = const TextEditingValue(text: '');

    exampleController = TextEditingController();
    exampleController.value = const TextEditingValue(text: '');

    topicController = TextEditingController();
    topicController.value = const TextEditingValue(text: '');
  }

  @override
  void dispose() {
    wordController.dispose();
    meaningController.dispose();
    phoneticController.dispose();
    exampleController.dispose();
    topicController.dispose();
    super.dispose();
  }

  Future<void> _performLookup() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });
    try {
      Map<String, String> result = {};

      // Case 1: User entered English word → lookup Vietnamese + phonetic
      if (wordController.text.trim().isNotEmpty) {
        result = await TranslationService.lookupWord(
          wordController.text.trim(),
        );

        if (!mounted) return;
        if (result.containsKey('meaning')) {
          meaningController.text = result['meaning']!;
        }
        if (result.containsKey('phonetic')) {
          phoneticController.text = result['phonetic']!;
        }
      }
      // Case 2: User entered Vietnamese meaning → lookup English + phonetic
      else if (meaningController.text.trim().isNotEmpty) {
        result = await TranslationService.reverseLookup(
          meaningController.text.trim(),
        );

        if (!mounted) return;
        if (result.containsKey('word')) {
          wordController.text = result['word']!;
        }
        if (result.containsKey('phonetic')) {
          phoneticController.text = result['phonetic']!;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: Không thể lấy dữ liệu từ (${e.toString()})'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _translateExample() async {
    if (exampleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập câu ví dụ trước')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      isTranslatingExample = true;
    });

    try {
      final translatedText = await TranslationService.autoTranslate(
        exampleController.text.trim(),
      );

      if (!mounted) return;
      if (translatedText != null && translatedText.isNotEmpty) {
        // Collect keywords to highlight
        final keywords = <String>[];
        if (wordController.text.trim().isNotEmpty) {
          keywords.add(wordController.text.trim());
        }
        if (meaningController.text.trim().isNotEmpty) {
          keywords.add(meaningController.text.trim());
        }

        if (!mounted) return;

        // Show preview dialog if there are keywords
        if (keywords.isNotEmpty) {
          await _showTranslationPreview(translatedText, keywords);
        } else {
          // No keywords, just replace directly
          exampleController.text = translatedText;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể dịch câu ví dụ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() {
          isTranslatingExample = false;
        });
      }
    }
  }

  Future<void> _showTranslationPreview(
    String translatedText,
    List<String> keywords,
  ) async {
    // Find matching words
    final matches = TranslationService.findMatchingWords(
      translatedText,
      keywords,
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xem Trước Dịch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RichText(
                    text: _buildHighlightedText(translatedText, matches),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                exampleController.text = translatedText;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Xác Nhận'),
            ),
          ],
        );
      },
    );
  }

  TextSpan _buildHighlightedText(
    String text,
    List<Map<String, dynamic>> matches,
  ) {
    if (matches.isEmpty) {
      return TextSpan(text: text);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      final start = match['start'] as int;
      final end = match['end'] as int;
      final word = match['word'] as String;

      // Add text before match
      if (start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, start),
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
        );
      }

      // Add highlighted word
      spans.add(
        TextSpan(
          text: word,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      );

      lastEnd = end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: const TextStyle(fontWeight: FontWeight.normal),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Future<String?> _showTopicConfirmationDialog() async {
    // Get AI suggested topic
    final suggestedTopic = TopicClassifier.classifyWord(
      wordController.text,
      meaningController.text,
    );

    String selectedTopic = suggestedTopic;

    // Show confirmation dialog
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Phân loại từ'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI gợi ý: '),
                  const SizedBox(height: 8),
                  Text(
                    suggestedTopic,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Hoặc chọn loại khác:'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedTopic,
                    items: TopicClassifier.topics
                        .map(
                          (topic) => DropdownMenuItem(
                            value: topic,
                            child: Text(topic),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedTopic = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedTopic),
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _saveWord() async {
    try {
      final word = wordController.text.trim();
      final meaning = meaningController.text.trim();
      final phonetic = phoneticController.text.trim();
      final example = exampleController.text.trim();

      if (word.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập từ tiếng Anh')),
        );
        return;
      }

      if (example.isNotEmpty && !_exampleContainsWord(word, example)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Câu ví dụ phải chứa từ "$word" mới hợp lệ để hiển thị',
            ),
          ),
        );
        return;
      }

      // Show topic confirmation dialog
      final selectedTopic = await _showTopicConfirmationDialog();
      if (selectedTopic == null) {
        // User cancelled
        return;
      }

      await widget.repository.addManualCard(
        word: word,
        meaning: meaning,
        phonetic: phonetic,
        example: example,
        topic: selectedTopic,
        imageBytes: _selectedImageBytes,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onWordAdded();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  bool _exampleContainsWord(String word, String example) {
    final normalizedWord = word.trim().toLowerCase();
    if (normalizedWord.isEmpty) {
      return false;
    }
    final normalizedExample = example.trim().toLowerCase();
    if (normalizedExample.isEmpty) {
      return true;
    }

    final escapedWord = RegExp.escape(normalizedWord);
    final boundaryPattern = RegExp(
      '(^|[^a-z0-9])' + escapedWord + r'([^a-z0-9]|$)',
      caseSensitive: false,
    );
    return boundaryPattern.hasMatch(normalizedExample);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!mounted) return;
    setState(() {
      isPickingImage = true;
    });

    try {
      if (source == ImageSource.camera) {
        final capturedBytes = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const _QuickCameraCaptureScreen(),
          ),
        );
        if (capturedBytes != null && mounted) {
          setState(() {
            _selectedImageBytes = capturedBytes;
          });
        }
        return;
      }

      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1440,
        imageQuality: 88,
      );
      if (image == null || !mounted) {
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể chọn ảnh: $error')));
    } finally {
      if (mounted) {
        setState(() {
          isPickingImage = false;
        });
      }
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      autofocus: false,
      enableInteractiveSelection: true,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thêm từ mới',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Nhập từ tiếng Anh hoặc nghĩa Việt, rồi bấm "Tìm" để auto-fill tất cả field.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  wordController,
                  'Từ tiếng Anh *',
                  Icons.text_fields,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed:
                      isLoading ||
                          (wordController.text.trim().isEmpty &&
                              meaningController.text.trim().isEmpty)
                      ? null
                      : _performLookup,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Tìm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            meaningController,
            'Nghĩa tiếng Việt *',
            Icons.translate,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            phoneticController,
            'Phiên âm',
            Icons.record_voice_over,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  exampleController,
                  'Câu ví dụ',
                  Icons.short_text,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: isTranslatingExample ? null : _translateExample,
                    icon: isTranslatingExample
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.translate, size: 20),
                    label: const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ảnh minh họa',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 72,
                        height: 72,
                        color: Colors.blue[50],
                        child: _selectedImageBytes == null
                            ? const Icon(
                                Icons.image_outlined,
                                color: Colors.blueGrey,
                              )
                            : Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.cover,
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
                                : () => _pickImage(ImageSource.camera),
                            icon: isPickingImage
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                            label: const Text('Chụp ảnh'),
                          ),
                          OutlinedButton.icon(
                            onPressed: isPickingImage
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: isPickingImage
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_library_outlined),
                            label: const Text('Chọn ảnh'),
                          ),
                          if (_selectedImageBytes != null)
                            TextButton.icon(
                              onPressed: () async {
                                final confirmed =
                                    await _confirmDeleteImageDialog();
                                if (!confirmed || !mounted) {
                                  return;
                                }
                                setState(() {
                                  _selectedImageBytes = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Xóa ảnh'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(topicController, 'Chủ đề', Icons.category_outlined),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Hủy'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saveWord,
                icon: const Icon(Icons.add),
                label: const Text('Lưu từ mới'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCameraCaptureScreen extends StatefulWidget {
  const _QuickCameraCaptureScreen();

  @override
  State<_QuickCameraCaptureScreen> createState() =>
      _QuickCameraCaptureScreenState();
}

class _QuickCameraCaptureScreenState extends State<_QuickCameraCaptureScreen> {
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
