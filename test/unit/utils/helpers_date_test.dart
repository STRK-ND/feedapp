import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/utils/helpers.dart';

void main() {
  group('Helpers - Date Formatting', () {
    group('formatTimeAgo', () {
      test('Should return "Just now" for recent time', () {
        final now = DateTime.now();
        expect(Helpers.formatTimeAgo(now), 'Just now');
      });

      test('Should return "Xm ago" for minutes', () {
        final time = DateTime.now().subtract(const Duration(minutes: 5));
        expect(Helpers.formatTimeAgo(time), '5m ago');
      });

      test('Should return "5m ago" for 5 minutes ago', () {
        final time = DateTime.now().subtract(const Duration(minutes: 5));
        final result = Helpers.formatTimeAgo(time);
        expect(result, '5m ago');
      });

      test('Should return "Xh ago" for hours', () {
        final time = DateTime.now().subtract(const Duration(hours: 3));
        expect(Helpers.formatTimeAgo(time), '3h ago');
      });

      test('Should return "Xd ago" for days', () {
        final time = DateTime.now().subtract(const Duration(days: 2));
        expect(Helpers.formatTimeAgo(time), '2d ago');
      });

      test('Should return formatted date for old dates', () {
        final time = DateTime(2023, 12, 15);
        final result = Helpers.formatTimeAgo(time);
        expect(result, '15/12/2023');
      });

      test('Should return "1d ago" for exactly 1 day', () {
        final time = DateTime.now().subtract(const Duration(days: 1));
        expect(Helpers.formatTimeAgo(time), '1d ago');
      });

      test('Should return "6d ago" for 6 days (boundary case)', () {
        final time = DateTime.now().subtract(const Duration(days: 6));
        expect(Helpers.formatTimeAgo(time), '6d ago');
      });
    });

    group('formatDate', () {
      test('Should format date correctly', () {
        final date = DateTime(2024, 1, 15, 14, 30);
        expect(Helpers.formatDate(date), '15/1/2024 14:30');
      });

      test('Should format date with single digit hour', () {
        final date = DateTime(2024, 1, 15, 9, 5);
        expect(Helpers.formatDate(date), '15/1/2024 09:05');
      });

      test('Should format date with single digit minute', () {
        final date = DateTime(2024, 1, 15, 14, 9);
        expect(Helpers.formatDate(date), '15/1/2024 14:09');
      });
    });

    group('parseDate', () {
      test('Should parse ISO8601 date string', () {
        final result = Helpers.parseDate('2024-01-15T10:30:00Z');
        expect(result, DateTime.utc(2024, 1, 15, 10, 30));
      });

      test('Should parse date with timezone offset', () {
        final result = Helpers.parseDate('2024-01-15T10:30:00+05:30');
        expect(result, DateTime.utc(2024, 1, 15, 5, 0));
      });

      test('Should handle invalid format by returning DateTime.now()', () {
        final beforeCall = DateTime.now();
        final result = Helpers.parseDate('invalid-date');
        final afterCall = DateTime.now();
        expect(result.isAfter(beforeCall.subtract(const Duration(seconds: 1))), true);
        expect(result.isBefore(afterCall.add(const Duration(seconds: 1))), true);
      });
    });

  });
}
