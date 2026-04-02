import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/saved_card.dart';
import '../services/saved_cards_repository.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final SavedCardsRepository _repository = SavedCardsRepository.instance;
  late final Stream<List<SavedCard>> _cardsStream = _repository.watchCards();

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
        child: StreamBuilder<List<SavedCard>>(
          stream: _cardsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _CenteredMessage(
                message: 'Không thể tải dữ liệu: ${snapshot.error}',
                icon: Icons.error_outline,
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final cards = snapshot.data!;
            if (cards.isEmpty) {
              return _CenteredMessage(
                message:
                    'Chưa có thẻ nào. Hãy mở camera AI để tạo thẻ đầu tiên!',
                icon: Icons.menu_book,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return _CardListTile(card: card);
              },
            );
          },
        ),
      ),
    );
  }
}

class _CardListTile extends StatelessWidget {
  const _CardListTile({required this.card});

  final SavedCard card;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDetail(context, card),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
            _CardThumbnail(imageUrl: card.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.word,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if ((card.wordType ?? '').isNotEmpty)
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
                            card.wordType!,
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
                    card.meaning,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.phonetic,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, SavedCard card) {
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
          onTap: () => Navigator.of(context).pop(),
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _CardDetailImage(imageUrl: card.imageUrl),
                                const SizedBox(height: 22),
                                Text(
                                  card.word,
                                  style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  card.phonetic,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  card.meaning,
                                  style: const TextStyle(fontSize: 28),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  card.example,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if ((card.topic).isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Chip(
                                    label: Text(card.topic),
                                    backgroundColor: Colors.blue[50],
                                  ),
                                ],
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
                            onPressed: () => Navigator.of(context).pop(),
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
              child: Container(color: Colors.black.withOpacity(0)),
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
}

class _CardThumbnail extends StatelessWidget {
  const _CardThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? const Icon(Icons.image, color: Colors.blueGrey)
          : null,
    );
  }
}

class _CardDetailImage extends StatelessWidget {
  const _CardDetailImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
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