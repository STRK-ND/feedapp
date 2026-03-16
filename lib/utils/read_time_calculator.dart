/// Calculates read time for articles
class ReadTimeCalculator {
 static const int _wordsPerMinute = 200; // Average reading speed

 static int calculateReadTime(String? description) {
 final text = description ?? '';
 if (text.isEmpty) return 1;

 final wordCount = text.split(RegExp(r'\s+')).length;
 final minutes = (wordCount / _wordsPerMinute).ceil();

 return minutes < 1 ? 1 : minutes;
 }
}
