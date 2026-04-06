class Expense {
  final String id;
  final String store;
  final double amount;
  final String category;
  final DateTime date;
  final String? imagePath;
  final bool isManual;

  Expense({
    required this.id,
    required this.store,
    required this.amount,
    required this.category,
    required this.date,
    this.imagePath,
    required this.isManual,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'store': store,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'imagePath': imagePath,
        'isManual': isManual,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        store: json['store'],
        amount: (json['amount'] as num).toDouble(),
        category: json['category'],
        date: DateTime.parse(json['date']),
        imagePath: json['imagePath'],
        isManual: json['isManual'] ?? false,
      );
}