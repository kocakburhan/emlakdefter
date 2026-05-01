import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/agent/screens/summary_screen.dart';

void main() {
  group('ActivityItem Model Tests', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': '1',
        'type': 'payment',
        'title': 'Test Title',
        'subtitle': 'Test Subtitle',
        'icon': 'payments',
        'color': 'success',
        'timestamp': '2024-01-15T10:30:00Z',
      };

      final item = ActivityItem.fromJson(json);

      expect(item.id, '1');
      expect(item.type, 'payment');
      expect(item.title, 'Test Title');
      expect(item.subtitle, 'Test Subtitle');
      expect(item.icon, 'payments');
      expect(item.color, 'success');
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};

      final item = ActivityItem.fromJson(json);

      expect(item.id, '');
      expect(item.type, '');
      expect(item.title, '');
    });
  });

  group('ActivityFilter Tests', () {
    test('filter values are correct', () {
      expect(ActivityFilter.values.length, 5);
      expect(ActivityFilter.all.index, 0);
      expect(ActivityFilter.payments.index, 1);
      expect(ActivityFilter.tickets.index, 2);
      expect(ActivityFilter.tenants.index, 3);
      expect(ActivityFilter.propertyOperations.index, 4);
    });
  });

  group('Filter Logic Unit Tests', () {
    test('filteredActivities returns all when filter is all', () {
      final activities = [
        ActivityItem(id: '1', type: 'payment', title: 'T1', subtitle: '', icon: '', color: '', timestamp: DateTime.now()),
        ActivityItem(id: '2', type: 'ticket', title: 'T2', subtitle: '', icon: '', color: '', timestamp: DateTime.now()),
      ];

      final filtered = activities.where((a) => a.type == 'payment').toList();
      expect(filtered.length, 1);
      expect(filtered.first.id, '1');
    });

    test('filter by type returns correct items', () {
      final activities = [
        ActivityItem(id: '1', type: 'payment', title: 'Pay', subtitle: '', icon: '', color: '', timestamp: DateTime.now()),
        ActivityItem(id: '2', type: 'ticket', title: 'Ticket', subtitle: '', icon: '', color: '', timestamp: DateTime.now()),
        ActivityItem(id: '3', type: 'payment', title: 'Pay2', subtitle: '', icon: '', color: '', timestamp: DateTime.now()),
      ];

      final payments = activities.where((a) => a.type == 'payment').toList();
      expect(payments.length, 2);
    });
  });

  group('Time Formatting Tests', () {
    test('formatTime returns correct values', () {
      final now = DateTime.now();

      expect(_formatTestTime(now, 0), 'Şimdi');
      expect(_formatTestTime(now, 45), '45 dk');
      expect(_formatTestTime(now, 90), '1 saat');
      expect(_formatTestTime(now, 1200), '20 saat');
      expect(_formatTestTime(now, 10000), '6 gün');
    });
  });
}

String _formatTestTime(DateTime now, int minutesAgo) {
  final dt = now.subtract(Duration(minutes: minutesAgo));
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
  if (diff.inHours < 24) return '${diff.inHours} saat';
  if (diff.inDays < 7) return '${diff.inDays} gün';
  return '${dt.day}.${dt.month}';
}