import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/rss_source.dart';

void main() {
  group('RssSource Model', () {
    late RssSource testSource;

    setUp(() {
      testSource = RssSource(
        id: 'source-1',
        name: 'Tech News',
        url: 'https://example.com/tech/feed.xml',
        category: 'Technology',
        color: Color(0xFF2196F3),
        icon: IconData(0xE000, fontFamily: 'MaterialIcons'),
      );
    });

    test('Should create RssSource with correct values', () {
      expect(testSource.id, 'source-1');
      expect(testSource.name, 'Tech News');
      expect(testSource.url, 'https://example.com/tech/feed.xml');
      expect(testSource.category, 'Technology');
      expect(testSource.color.value, 0xFF2196F3);
      expect(testSource.icon.codePoint, 0xE000);
    });

    test('Should convert to JSON correctly', () {
      final json = testSource.toJson();

      expect(json['id'], 'source-1');
      expect(json['name'], 'Tech News');
      expect(json['url'], 'https://example.com/tech/feed.xml');
      expect(json['category'], 'Technology');
      expect(json['color'], 0xFF2196F3);
      expect(json['icon'], 0xE000);
    });

    test('Should create RssSource from JSON correctly', () {
      final json = {
        'id': 'source-2',
        'name': 'Science Weekly',
        'url': 'https://example.com/science/feed.xml',
        'category': 'Science',
        'color': 0xFF4CAF50,
        'icon': 0xE000,
      };

      final source = RssSource.fromJson(json);

      expect(source.id, 'source-2');
      expect(source.name, 'Science Weekly');
      expect(source.url, 'https://example.com/science/feed.xml');
      expect(source.category, 'Science');
      expect(source.color.value, 0xFF4CAF50);
      expect(source.icon.codePoint, 0xE000);
    });

    test('Should use default values for missing fields in fromJson', () {
      final json = {
        'id': 'source-3',
      };

      final source = RssSource.fromJson(json);

      expect(source.id, 'source-3');
      expect(source.name, 'Unknown'); // default
      expect(source.url, ''); // default
      expect(source.category, 'General'); // default
      expect(source.color.value, 0xFF000000); // default
      expect(source.icon.codePoint, 0xE000); // default
    });

    test('Should create copy with updated values', () {
      final updated = testSource.copyWith(
        name: 'Updated Tech News',
        color: Color(0xFFFF5722),
      );

      expect(updated.id, testSource.id); // unchanged
      expect(updated.name, 'Updated Tech News'); // changed
      expect(updated.url, testSource.url); // unchanged
      expect(updated.category, testSource.category); // unchanged
      expect(updated.color.value, 0xFFFF5722); // changed
      expect(updated.icon.codePoint, testSource.icon.codePoint); // unchanged
    });
  });
}
