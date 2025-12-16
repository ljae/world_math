import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/landing_screen.dart';
import 'screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Kakao SDK
  // TODO: Replace with your actual Native App Key from Kakao Developers Console
  KakaoSdk.init(nativeAppKey: 'YOUR_KAKAO_NATIVE_APP_KEY');

  // Upload problems from JSON files to Firebase (최초 1회만 실행)
  // ✅ JSON 데이터가 Firebase에 업로드 완료되어 주석 처리됨
  // try {
  //   await FirestoreService().uploadProblemsFromJson();
  //   print('Problems uploaded from JSON successfully!');
  // } catch (e) {
  //   print('Error uploading problems: $e');
  // }

  // Seed the database with problems and dummy users (최초 1회만 실행)
  // ✅ 데이터가 Firebase에 업로드 완료되어 주석 처리됨
  // try {
  //   await FirestoreService().seedDatabase();
  //   await FirestoreService().seedDummyUsers();
  //   print('Database seeded successfully!');
  // } catch (e) {
  //   print('Error seeding database: $e');
  // }

  await initializeDateFormatting('ko_KR', null);
  runApp(const WorldMathApp());
}

class WorldMathApp extends StatelessWidget {
  const WorldMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대치동 김부장 아들의 세상수학',
      theme: AppTheme.lightTheme,
      home: const LandingScreen(),
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
    );
  }
}

// Trigger new build
