import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/rss_source.dart';

void main() {
  group('RssSource Model', () {
    late RssSource testSource;

    setUp(() {
      testSource = const RssSource(
        id: 'test-source-1',
        name: 'Test Feed',
        url: 'https://example.com/feed.xml',
        category: 'Tech',
        color: Color(0xFF3B82F6),
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

    test('Should be const constructible', () {
      const source = RssSource(
        id: 'const-test',
        name: 'Const Feed',
        url: 'https://example.com/rss',
        category: 'News',
        color: Color(0xFFDC2626),
        icon: Icons.newspaper,
      );
      expect(source.id, 'const-test');
    });
  });
}
