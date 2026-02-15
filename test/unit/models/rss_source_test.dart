import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/rss_source.dart';

void main() {
  group('RssSource Model', () {
    late RssSource testSource;

    setUp(() {
      testSource = RssSource(
        id: 'test-source-1',
        name: 'Test Feed',
        url: 'https://example.com/feed.xml',
        category: 'Tech',
        color: const Color(0xFF3B82F6),
        icon: Icons.computer,
      );
    });

    test('Should create RssSource with correct values', () {
      expect(testSource.id, 'test-source-1');
      expect(testSource.name, 'Test Feed');
      expect(testSource.url, 'https://example.com/feed.xml');
      expect(testSource.category, 'Tech');
      expect(testSource.color, const Color(0xFF3B82F6));
      expect(testSource.icon, Icons.computer);
    });

    test('Should convert to JSON correctly', () {
      final json = testSource.toJson();

      expect(json['id'], 'test-source-1');
      expect(json['name'], 'Test Feed');
      expect(json['url'], 'https://example.com/feed.xml');
      expect(json['category'], 'Tech');
      expect(json['color'], 0xFF3B82F6); // ARGB32
      expect(json['icon'], Icons.computer.codePoint);
    });

    test('Should create RssSource from JSON correctly', () {
      final json = {
        'id': 'test-source-2',
        'name': 'Another Feed',
        'url': 'https://example.com/feed2.xml',
        'category': 'News',
        'color': 0xFFDC2626,
        'icon': Icons.article_rounded.codePoint,
      };

      final source = RssSource.fromJson(json);

      expect(source.id, 'test-source-2');
      expect(source.name, 'Another Feed');
      expect(source.url, 'https://example.com/feed2.xml');
      expect(source.category, 'News');
      expect(source.color, const Color(0xFFDC2626));
      expect(source.icon, Icons.article_rounded);
    });

    test('Should use default values for missing fields in fromJson', () {
      final json = {
        'id': 'minimal-source',
        'name': 'Minimal Feed',
      };

      final source = RssSource.fromJson(json);

      expect(source.id, 'minimal-source');
      expect(source.name, 'Minimal Feed');
      expect(source.url, ''); // default
      expect(source.category, 'General'); // default
      expect(source.color, const Color(0xFF000000)); // default
      expect(source.icon, const IconData(0xE000, fontFamily: 'MaterialIcons')); // default
    });

    test('Should create copy with updated values', () {
      final updated = testSource.copyWith(
        name: 'Updated Feed',
        category: 'Science',
      );

      expect(updated.id, testSource.id); // unchanged
      expect(updated.name, 'Updated Feed'); // changed
      expect(updated.url, testSource.url); // unchanged
      expect(updated.category, 'Science'); // changed
      expect(updated.color, testSource.color); // unchanged
    });
  });
}
