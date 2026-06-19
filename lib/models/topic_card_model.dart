class TopicCard {
  final String id;
  final String category;
  final String question;
  final bool isCustom;
  final bool isLiked;

  TopicCard({
    required this.id,
    required this.category,
    required this.question,
    this.isCustom = false,
    this.isLiked = false,
  });

  TopicCard copyWith({
    String? id,
    String? category,
    String? question,
    bool? isCustom,
    bool? isLiked,
  }) {
    return TopicCard(
      id: id ?? this.id,
      category: category ?? this.category,
      question: question ?? this.question,
      isCustom: isCustom ?? this.isCustom,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'question': question,
      'isCustom': isCustom,
      'isLiked': isLiked,
    };
  }

  factory TopicCard.fromJson(Map<String, dynamic> json) {
    return TopicCard(
      id: json['id'] ?? '',
      category: json['category'] ?? '',
      question: json['question'] ?? '',
      isCustom: json['isCustom'] ?? false,
      isLiked: json['isLiked'] ?? false,
    );
  }
}
