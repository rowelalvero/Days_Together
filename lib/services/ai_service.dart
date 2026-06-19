import 'dart:math';

class AIService {
  static const List<String> _romanticQuotes = [
    "I saw that you were perfect, and so I loved you. Then I saw that you were not perfect and I loved you even more.",
    "If I know what love is, it is because of you.",
    "You are my today and all of my tomorrows.",
    "In all the world, there is no heart for me like yours. In all the world, there is no love for you like mine.",
  ];

  static Future<String> generateLoveLetter({
    required String memoryTitle,
    required String mood,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    final random = Random();
    final quote = _romanticQuotes[random.nextInt(_romanticQuotes.length)];

    String moodSection = "";
    if (mood.contains('😍') || mood.toLowerCase().contains('happy') || mood.toLowerCase().contains('amazing')) {
      moodSection = "My heart was overflowed with pure joy and absolute bliss. Looking at you, feeling your warmth, I knew that every single second with you is a gift I will treasure forever.";
    } else if (mood.contains('😢') || mood.toLowerCase().contains('sad') || mood.toLowerCase().contains('low')) {
      moodSection = "Even on the quietest, darkest days, you are the lighthouse that guides me home. Sharing that moment with you made the weight of the world melt away into soft whispers.";
    } else {
      moodSection = "It was a simple, beautiful chapter in our story. Just being by your side, living in the quiet cadence of your breathing, is all the comfort my soul will ever need.";
    }

    return '''My Dearest,

Today, I found myself reminiscing about that beautiful moment we shared: "$memoryTitle". 

It feels like just yesterday we were painting our canvas with these sweet memories. $moodSection

As the poet once wrote: "$quote"

Thank you for being my partner, my best friend, and my greatest adventure. Every day by your side makes me realize how incredibly lucky I am to walk this path of life with you.

With all my love, forever and always,
Your Partner ❤️''';
  }

  static List<String> generateInsights({
    required int totalDays,
    required int totalMemories,
    required String commonMood,
    required int totalBucketItems,
    required int completedBucketItems,
  }) {
    final insights = <String>[];

    insights.add("💫 You've been walking hand-in-hand for $totalDays days! That's a beautiful journey of shared smiles and whispered promises.");

    if (totalMemories > 0) {
      insights.add("📸 You have preserved $totalMemories precious memories on your shared timeline. Your history is rich and beautiful!");
    } else {
      insights.add("🎨 Your memory timeline is a blank canvas. Start logging your dates, trips, and daily thoughts to paint your story!");
    }

    if (commonMood.isNotEmpty) {
      insights.add("💖 The dominant emotion of your relationship is $commonMood. Your hearts beat in beautiful, happy harmony!");
    }

    if (totalBucketItems > 0) {
      final percent = ((completedBucketItems / totalBucketItems) * 100).toInt();
      insights.add("🎯 You have achieved $percent% of your shared bucket list dreams! ($completedBucketItems completed out of $totalBucketItems). Keep dreaming together!");
    } else {
      insights.add("🌟 You haven't added any adventures to your bucket list yet. Head over to the Together tab and dream big!");
    }

    if (totalDays > 365) {
      insights.add("🌹 You've passed the one-year milestone! Your love is deep-rooted, growing stronger and more beautiful with each passing season.");
    } else {
      insights.add("🌱 Your love is in its beautiful, fresh blossoming phase. Enjoy every single moment of discovery!");
    }

    return insights;
  }
}
