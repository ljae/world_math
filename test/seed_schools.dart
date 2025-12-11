import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:world_math/services/firestore_service.dart';
import 'package:world_math/models/models.dart';
import 'package:world_math/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final service = FirestoreService();
  
  final schools = [
    School(id: '', name: 'Seoul High School', region: 'Seoul', address: '123 Seoul St'),
    School(id: '', name: 'Busan High School', region: 'Busan', address: '456 Busan Rd'),
    School(id: '', name: 'Daegu High School', region: 'Daegu', address: '789 Daegu Ave'),
    School(id: '', name: 'Incheon High School', region: 'Incheon', address: '101 Incheon Blvd'),
    School(id: '', name: 'Gwangju High School', region: 'Gwangju', address: '202 Gwangju Ln'),
  ];

  print('Seeding schools...');
  for (var school in schools) {
    await service.addSchool(school);
    print('Added ${school.name}');
  }
  print('Done!');
}
