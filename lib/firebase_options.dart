import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Firebase configuration for the In-Class 15 project.
///
/// Project: inclass-15-mad (display name: inclass-15)
/// Android app: com.aditauqir.inclass_15
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is only configured for Android in this classroom build.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC1-D9TUML_Gps2Ou5J0NtS0irID32elUE',
    appId: '1:347403910500:android:ea8c7e147e56a23b504e71',
    messagingSenderId: '347403910500',
    projectId: 'inclass-15-mad',
    storageBucket: 'inclass-15-mad.firebasestorage.app',
  );
}
