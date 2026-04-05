import 'package:flutter/foundation.dart';

enum FirestoreSyncAction { idle, reading, writing, success, error }

class FirestoreSyncState {
  const FirestoreSyncState({
    required this.action,
    required this.message,
    this.path,
    required this.updatedAt,
  });

  final FirestoreSyncAction action;
  final String message;
  final String? path;
  final DateTime updatedAt;
}

class FirestoreSyncStatus {
  FirestoreSyncStatus._();

  static final FirestoreSyncStatus instance = FirestoreSyncStatus._();

  final ValueNotifier<FirestoreSyncState> statusNotifier = ValueNotifier<FirestoreSyncState>(
    FirestoreSyncState(
      action: FirestoreSyncAction.idle,
      message: 'Firestore chưa đồng bộ',
      updatedAt: DateTime.now(),
    ),
  );

  void reportReading({required String path, required String reason}) {
    _update(
      action: FirestoreSyncAction.reading,
      path: path,
      message: 'Đang đọc Firestore: $reason',
    );
  }

  void reportWriting({required String path, required String reason}) {
    _update(
      action: FirestoreSyncAction.writing,
      path: path,
      message: 'Đang ghi Firestore: $reason',
    );
  }

  void reportSuccess({required String path, required String message}) {
    _update(action: FirestoreSyncAction.success, path: path, message: message);
  }

  void reportError({
    required String path,
    required String operation,
    required Object error,
  }) {
    _update(
      action: FirestoreSyncAction.error,
      path: path,
      message: 'Lỗi Firestore ($operation): $error',
    );
  }

  void _update({
    required FirestoreSyncAction action,
    required String message,
    String? path,
  }) {
    statusNotifier.value = FirestoreSyncState(
      action: action,
      message: message,
      path: path,
      updatedAt: DateTime.now(),
    );
    debugPrint('[FirestoreSync][$action] $message | path=$path');
  }
}
