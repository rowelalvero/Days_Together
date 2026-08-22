/// A single fun-statistic row shown on the relationship duration screen
/// (e.g. "🌅 Sunrises Together: 1,204"). Values are computed at render time
/// from the couple's start date -- this type just carries the display
/// triple, it is not itself a catalog entry.
class FunStatItem {
  final String emoji;
  final String label;
  final String value;
  FunStatItem(this.emoji, this.label, this.value);
}

/// One entry in [relationshipMilestoneCatalog]: either a fixed day-count
/// milestone (e.g. "100 Days Together") or an anniversary year, in which
/// case its achievement date is computed from the couple's start date via
/// `DateHelper.getAnniversaryDate` rather than from [targetDays] directly.
class AchievedMilestone {
  final String title;
  final int targetDays;
  final bool isAnniversary;
  final int annivYear;

  const AchievedMilestone(
    this.title,
    this.targetDays, {
    this.isAnniversary = false,
    this.annivYear = 0,
  });
}

/// The relationship duration screen's "Milestones Achieved" timeline,
/// filtered down to whichever of these the couple has actually reached.
/// Moved out of `relationship_duration_screen.dart` (Migration Phase 8) so
/// the milestone set is data, not inline widget-building logic.
const List<AchievedMilestone> relationshipMilestoneCatalog = [
  AchievedMilestone('First Day ❤️', 0),
  AchievedMilestone('30 Days Together 🎉', 30),
  AchievedMilestone('100 Days Together 💫', 100),
  AchievedMilestone('1 Year Anniversary 🌹', 365, isAnniversary: true, annivYear: 1),
  AchievedMilestone('500 Days Together ✨', 500),
  AchievedMilestone('1,000 Days Together 👑', 1000),
  AchievedMilestone('2 Years Anniversary 💍', 730, isAnniversary: true, annivYear: 2),
  AchievedMilestone('1,500 Days Together 🌟', 1500),
  AchievedMilestone('3 Years Anniversary 🏹', 1095, isAnniversary: true, annivYear: 3),
  AchievedMilestone('2,000 Days Together 🌈', 2000),
  AchievedMilestone('4 Years Anniversary 🥂', 1461, isAnniversary: true, annivYear: 4),
  AchievedMilestone('2,500 Days Together 🛸', 2500),
  AchievedMilestone('5 Years Anniversary 🪐', 1826, isAnniversary: true, annivYear: 5),
  AchievedMilestone('3,000 Days Together 🛸', 3000),
  AchievedMilestone('10 Years Anniversary 💎', 3652, isAnniversary: true, annivYear: 10),
];
