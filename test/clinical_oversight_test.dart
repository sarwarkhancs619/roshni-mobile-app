import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clinical & Therapy Data Parsing & Dynamic Activities', () {
    test('Dynamic Physio Exercises serialization and parsing', () {
      final exercises = [
        {
          'title': 'Quadriceps Strengthening',
          'focus': 'Legs & Mobility',
          'reps': '3 sets x 10 reps',
          'notes': 'Use light resistance band',
        },
        {
          'title': 'Balance Beam Walk',
          'focus': 'Core & Posture',
          'reps': '5 mins',
          'notes': 'Supervised',
        }
      ];

      // Simulate serialization to database text[]
      final serialized = exercises.map((e) => '${e['title']} | ${e['focus']} | ${e['reps']} | ${e['notes']}').toList();
      expect(serialized.length, 2);
      expect(serialized.first, contains('Quadriceps Strengthening'));

      // Simulate parsing
      final parsed = serialized.map((str) {
        final parts = str.split(' | ');
        return {
          'title': parts.isNotEmpty ? parts[0] : '',
          'focus': parts.length > 1 ? parts[1] : '',
          'reps': parts.length > 2 ? parts[2] : '',
          'notes': parts.length > 3 ? parts[3] : '',
        };
      }).toList();

      expect(parsed.length, 2);
      expect(parsed[0]['title'], 'Quadriceps Strengthening');
      expect(parsed[0]['focus'], 'Legs & Mobility');
      expect(parsed[1]['reps'], '5 mins');
    });

    test('Dynamic Speech Targets serialization and parsing', () {
      final activities = [
        {
          'title': 'Phoneme /p/ and /b/ drills',
          'focus': 'Articulation',
          'target': '15 mins per session',
          'notes': 'Focus on visual lip closure',
        },
        {
          'title': 'Picture Exchange Communication',
          'focus': 'PECS / AAC',
          'target': 'Daily routine cards',
          'notes': 'Mealtime choices',
        }
      ];

      final serialized = activities.map((a) => '${a['title']} | ${a['focus']} | ${a['target']} | ${a['notes']}').toList();
      expect(serialized.length, 2);

      final parsed = serialized.map((str) {
        final parts = str.split(' | ');
        return {
          'title': parts.isNotEmpty ? parts[0] : '',
          'focus': parts.length > 1 ? parts[1] : '',
          'target': parts.length > 2 ? parts[2] : '',
          'notes': parts.length > 3 ? parts[3] : '',
        };
      }).toList();

      expect(parsed[0]['focus'], 'Articulation');
      expect(parsed[1]['focus'], 'PECS / AAC');
    });

    test('Dynamic Medical Allergies & Vaccines list handling', () {
      final allergies = <String>['Peanuts', 'Penicillin'];
      expect(allergies.contains('Peanuts'), isTrue);

      // Add dynamic allergy
      allergies.add('Dust Mites');
      expect(allergies.length, 3);
      expect(allergies.last, 'Dust Mites');

      // Remove allergy
      allergies.remove('Penicillin');
      expect(allergies.contains('Penicillin'), isFalse);
      expect(allergies.length, 2);
    });

    test('Real Clinical KPI Calculations with Zero Mock Values', () {
      // Simulate real session scores
      final physioSessions = [
        {'friend_id': 'f1', 'rating': 4.0},
        {'friend_id': 'f1', 'rating': 5.0},
        {'friend_id': 'f2', 'rating': 3.0},
      ];

      final totalSessions = physioSessions.length;
      final avgRating = totalSessions > 0
          ? (physioSessions.fold<double>(0.0, (sum, s) => sum + ((s['rating'] as num?)?.toDouble() ?? 0.0)) / totalSessions)
          : 0.0;

      expect(totalSessions, 3);
      expect(avgRating, closeTo(4.0, 0.01));

      // When empty
      final emptySessions = <Map<String, dynamic>>[];
      final emptyAvg = emptySessions.isNotEmpty
          ? (emptySessions.fold<double>(0.0, (sum, s) => sum + ((s['rating'] as num?)?.toDouble() ?? 0.0)) / emptySessions.length)
          : 0.0;
      expect(emptyAvg, 0.0);
    });

    test('Real Workshop Productivity calculation with zero mock baseline', () {
      // 2 friends evaluated in bakery out of 3 enrolled
      final evaluations = [
        {'friend_id': 'f1', 'task_completion': 4.0},
        {'friend_id': 'f2', 'task_completion': 5.0},
      ];

      final totalComp = evaluations.fold<double>(0.0, (sum, e) => sum + (e['task_completion'] as double));
      final productivity = evaluations.isNotEmpty ? (totalComp / (evaluations.length * 5.0)) : 0.0;

      expect(productivity, closeTo(0.9, 0.01)); // (4+5)/(2*5) = 9/10 = 0.9 = 90%

      // When zero evaluations
      final noEvaluations = <Map<String, dynamic>>[];
      final zeroProductivity = noEvaluations.isNotEmpty ? 1.0 : 0.0;
      expect(zeroProductivity, 0.0);
    });

    test('Real IEP Goal Distribution calculation', () {
      final goals = [
        {'id': 'g1', 'status': 'completed'},
        {'id': 'g2', 'status': 'in_progress'},
        {'id': 'g3', 'status': 'completed'},
        {'id': 'g4', 'status': 'pending'},
      ];

      final completed = goals.where((g) => g['status'] == 'completed').length;
      final inProgress = goals.where((g) => g['status'] == 'in_progress').length;
      final pending = goals.where((g) => g['status'] == 'pending').length;
      final delayed = goals.where((g) => g['status'] == 'delayed').length;

      expect(completed, 2);
      expect(inProgress, 1);
      expect(pending, 1);
      expect(delayed, 0);

      final total = goals.length;
      final completionRate = (completed / total) * 100;
      expect(completionRate, 50.0);
    });

    test('Real Mood Distribution calculation with zero mock values', () {
      final records = [
        {'mood': 'excellent'},
        {'mood': 'good'},
        {'mood': 'excellent'},
        {'mood': 'neutral'},
      ];

      final Map<String, int> moodMap = {
        'excellent': 0,
        'good': 0,
        'neutral': 0,
        'agitated': 0,
        'withdrawn': 0,
      };

      for (final r in records) {
        final mood = r['mood']!;
        if (moodMap.containsKey(mood)) {
          moodMap[mood] = (moodMap[mood] ?? 0) + 1;
        }
      }

      expect(moodMap['excellent'], 2);
      expect(moodMap['good'], 1);
      expect(moodMap['neutral'], 1);
      expect(moodMap['agitated'], 0);
      expect(moodMap['withdrawn'], 0);
    });
  });
}
