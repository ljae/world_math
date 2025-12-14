import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'json_problem_loader.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 모든 학교 목록을 캐싱하기 위한 변수
  static List<School> _allSchools = [];

  // '포함(contains)' 방식으로 학교를 검색합니다.
  Future<List<School>> searchSchools(String query) async {
    if (query.isEmpty) return [];

    // 캐시된 학교 목록이 없으면 Firestore에서 가져옵니다.
    if (_allSchools.isEmpty) {
      final snapshot = await _db.collection('schools').get(const GetOptions(source: Source.server));
      _allSchools = snapshot.docs.map((doc) => School.fromMap(doc.data(), doc.id)).toList();
    }

    // 클라이언트 측에서 'contains' 필터링을 수행합니다.
    // school_name 또는 location에 query가 포함되어 있는지 확인합니다.
    return _allSchools.where((school) {
      final schoolNameLower = school.school_name.toLowerCase();
      final locationLower = school.location.toLowerCase();
      final queryLower = query.toLowerCase();
      return schoolNameLower.contains(queryLower) || locationLower.contains(queryLower);
    }).toList();
  }

  // Add a school (for seeding)
  Future<void> addSchool(School school) async {
    await _db.collection('schools').add(school.toMap());
  }

  // A function to seed the database with initial data.
  // This should be called once, manually, to populate the Firestore database.
  Future<void> seedDatabase() async {
    await uploadProblemsFromJson();
  }

  Future<List<Problem>> getProblemsByWeek(DateTime startOfWeek) async {
    final weekDayStrings = List.generate(
        7,
        (i) => startOfWeek.add(Duration(days: i)).toIso8601String().split('T')[0]
    );

    final snapshot = await _db
        .collection('problems')
        .where('date', whereIn: weekDayStrings)
        .orderBy('date', descending: false)
        .get(const GetOptions(source: Source.server));

    final problems = snapshot.docs.map((doc) => Problem.fromMap(doc.data())).toList();
    print('Returning ${problems.length} problems from Firebase Firestore');
    return problems;
  }
  
  Future<bool> hasRevealed(String userId, String problemId) async {
    final doc = await _db.collection('users').doc(userId).collection('revealed_problems').doc(problemId).get(const GetOptions(source: Source.server));
    return doc.exists;
  }

  Future<void> markRevealed(String userId, String problemId) async {
    await _db.collection('users').doc(userId).collection('revealed_problems').doc(problemId).set({});
  }
  
  Future<bool> hasSolved(String userId, String problemId) async {
    final doc = await _db.collection('users').doc(userId).collection('history').doc(problemId).get();
    return doc.exists;
  }
  
  Future<void> recordAttempt(String userId, String problemId, bool isCorrect, {int timeTakenSeconds = 0}) async {
    // Check if there's an existing attempt
    final docRef = _db.collection('users').doc(userId).collection('history').doc(problemId);
    final docSnapshot = await docRef.get();

    bool finalIsCorrect = isCorrect;

    if (docSnapshot.exists) {
      final existingAttempt = Attempt.fromMap(docSnapshot.data()!);
      // If previously incorrect, it stays incorrect forever.
      if (!existingAttempt.isCorrect) {
        finalIsCorrect = false;
      }
    }

    final attempt = Attempt(
      problemId: problemId,
      isCorrect: finalIsCorrect,
      solvedAt: DateTime.now(),
      timeTakenSeconds: timeTakenSeconds,
    );
    await docRef.set(attempt.toMap());
  }

  Future<List<Attempt>> getHistory(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('history')
        .orderBy('solvedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Attempt.fromMap(doc.data())).toList();
  }

  Future<Problem?> getProblemById(String problemId) async {
    print('Trying to load problem $problemId from Firebase Firestore...');

    final doc = await _db.collection('problems').doc(problemId).get(const GetOptions(source: Source.server));
    if (doc.exists) {
      final problem = Problem.fromMap(doc.data()!);
      print('Loaded $problemId from Firestore: economicInsightData = ${problem.economicInsightData != null ? "YES" : "NO"}');
      return problem;
    } else {
      print('Problem $problemId not found in Firestore.');
      return null;
    }
  }

  Future<void> updateUser(User user) async {
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  Future<User?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) {
      return User.fromMap(doc.data()!);
    }
    return null;
  }

  Future<List<RankingItem>> getRankings() async {
    final usersSnapshot = await _db.collection('users').get();
    final rankings = <RankingItem>[];

    for (final userDoc in usersSnapshot.docs) {
      final user = User.fromMap(userDoc.data());
      final historySnapshot = await _db
          .collection('users')
          .doc(user.id)
          .collection('history')
          .where('isCorrect', isEqualTo: true)
          .get();
      
      rankings.add(RankingItem(
        userId: user.id,
        nickname: user.nickname,
        schoolName: user.schoolName,
        solvedCount: historySnapshot.docs.length,
        rank: 0,
      ));
    }

    rankings.sort((a, b) => b.solvedCount.compareTo(a.solvedCount));

    final rankedList = <RankingItem>[];
    for (int i = 0; i < rankings.length; i++) {
      rankedList.add(RankingItem(
        userId: rankings[i].userId,
        nickname: rankings[i].nickname,
        schoolName: rankings[i].schoolName,
        solvedCount: rankings[i].solvedCount,
        rank: i + 1,
      ));
    }

    return rankedList;
  }

  Future<List<SchoolRankingItem>> getSchoolRankings() async {
    final individualRankings = await getRankings();
    final schoolMap = <String, Map<String, dynamic>>{};

    for (var item in individualRankings) {
      if (!schoolMap.containsKey(item.schoolName)) {
        schoolMap[item.schoolName] = {
          'totalSolvedCount': 0,
          'studentCount': 0,
        };
      }
      schoolMap[item.schoolName]!['totalSolvedCount'] += item.solvedCount;
      schoolMap[item.schoolName]!['studentCount'] += 1;
    }

    final schoolRankings = schoolMap.entries.map((entry) {
      return SchoolRankingItem(
        schoolName: entry.key,
        totalSolvedCount: entry.value['totalSolvedCount'],
        studentCount: entry.value['studentCount'],
        rank: 0,
      );
    }).toList();

    schoolRankings.sort((a, b) => b.totalSolvedCount.compareTo(a.totalSolvedCount));

    final rankedList = <SchoolRankingItem>[];
    for (int i = 0; i < schoolRankings.length; i++) {
      rankedList.add(SchoolRankingItem(
        schoolName: schoolRankings[i].schoolName,
        totalSolvedCount: schoolRankings[i].totalSolvedCount,
        studentCount: schoolRankings[i].studentCount,
        rank: i + 1,
      ));
    }

    return rankedList;
  }

  /// Upload all problems from JSON files to Firebase Firestore
  /// This will overwrite existing problems in Firestore
  Future<void> uploadProblemsFromJson() async {
    print('FirestoreService: Uploading problems from JSON files...');

    final jsonLoader = JsonProblemLoader();

    // List of problem IDs to upload (you can expand this list)
    final problemIds = [
      'p_20251117', 'p_20251118', 'p_20251119', 'p_20251120', 'p_20251121', 'p_20251122',
      'p_20251124', 'p_20251125', 'p_20251126', 'p_20251127', 'p_20251128',
      'p_20251201', 'p_20251202', 'p_20251203', 'p_20251204', 'p_20251205',
      'p_20251208', // Add more problem IDs as needed
    ];

    int uploadedCount = 0;
    int failedCount = 0;

    for (final problemId in problemIds) {
      try {
        final problem = await jsonLoader.loadProblem(problemId);
        if (problem != null) {
          await _db.collection('problems').doc(problemId).set(problem.toMap());
          print('✓ Uploaded $problemId (economicInsightData: ${problem.economicInsightData != null ? "YES" : "NO"})');
          uploadedCount++;
        } else {
          print('✗ Problem $problemId not found in JSON');
          failedCount++;
        }
      } catch (e) {
        print('✗ Error uploading $problemId: $e');
        failedCount++;
      }
    }

    print('FirestoreService: Upload complete! Uploaded: $uploadedCount, Failed: $failedCount');
  }

  // Seed dummy users for testing the ranking system
  Future<void> seedDummyUsers() async {
    print('FirestoreService: Seeding dummy users...');
    
    final dummyUsers = [
      User(
        id: 'dummy_user_1',
        nickname: '김수학',
        schoolName: '대치중학교',
      ),
      User(
        id: 'dummy_user_2',
        nickname: '이영재',
        schoolName: '대원중학교',
      ),
      User(
        id: 'dummy_user_3',
        nickname: '박천재',
        schoolName: '중대부중',
      ),
      User(
        id: 'dummy_user_4',
        nickname: '최고득점',
        schoolName: '대치중학교',
      ),
      User(
        id: 'dummy_user_5',
        nickname: '정수능만점',
        schoolName: '숙명여중',
      ),
    ];

    // Create users
    for (var user in dummyUsers) {
      await _db.collection('users').doc(user.id).set(user.toMap());
    }

    // Add some solved problems for each user
    final now = DateTime.now();
    
    // User 1: 15 solved problems
    for (int i = 0; i < 15; i++) {
      await _db.collection('users').doc('dummy_user_1').collection('history').add({
        'problemId': 'p_dummy_$i',
        'isCorrect': true,
        'solvedAt': now.subtract(Duration(days: i)).toIso8601String(),
        'timeTakenSeconds': 120 + i * 10,
      });
    }

    // User 2: 12 solved problems
    for (int i = 0; i < 12; i++) {
      await _db.collection('users').doc('dummy_user_2').collection('history').add({
        'problemId': 'p_dummy_$i',
        'isCorrect': true,
        'solvedAt': now.subtract(Duration(days: i)).toIso8601String(),
        'timeTakenSeconds': 150 + i * 10,
      });
    }

    // User 3: 18 solved problems (top scorer)
    for (int i = 0; i < 18; i++) {
      await _db.collection('users').doc('dummy_user_3').collection('history').add({
        'problemId': 'p_dummy_$i',
        'isCorrect': true,
        'solvedAt': now.subtract(Duration(days: i)).toIso8601String(),
        'timeTakenSeconds': 100 + i * 10,
      });
    }

    // User 4: 10 solved problems
    for (int i = 0; i < 10; i++) {
      await _db.collection('users').doc('dummy_user_4').collection('history').add({
        'problemId': 'p_dummy_$i',
        'isCorrect': true,
        'solvedAt': now.subtract(Duration(days: i)).toIso8601String(),
        'timeTakenSeconds': 180 + i * 10,
      });
    }

    // User 5: 14 solved problems
    for (int i = 0; i < 14; i++) {
      await _db.collection('users').doc('dummy_user_5').collection('history').add({
        'problemId': 'p_dummy_$i',
        'isCorrect': true,
        'solvedAt': now.subtract(Duration(days: i)).toIso8601String(),
        'timeTakenSeconds': 130 + i * 10,
      });
    }

    print('FirestoreService: Dummy users seeded successfully!');
  }
}
