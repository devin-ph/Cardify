import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyBmOK8pRZXLdD-kGCBA4bxvRI3SxKecwoU',
        appId: '1:833491715420:web:3058c0d4d4cf780cd7ad99',
        messagingSenderId: '833491715420',
        projectId: 'cardify-3d313',
        authDomain: 'cardify-3d313.firebaseapp.com',
        storageBucket: 'cardify-3d313.firebasestorage.app',
        measurementId: 'G-G2R6Q70N69',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have only been configured for Web in this project.',
        );
    }
  }
}
