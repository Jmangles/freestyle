import 'tip_type.dart';

class Tip {
  final int id;
  final String title;
  final String header;
  final String body;
  final bool status;
  final TipType type;
  final DateTime submittedOn;
  final int? submittedBy;
  final DateTime? approvedOn;
  final int? approvedBy;
  final DateTime? lastUpdated;
  final int? lastUpdatedBy;

  const Tip({
    required this.id,
    required this.title,
    required this.header,
    required this.body,
    required this.status,
    required this.type,
    required this.submittedOn,
    this.submittedBy,
    this.approvedOn,
    this.approvedBy,
    this.lastUpdated,
    this.lastUpdatedBy,
  });

  factory Tip.fromJson(Map<String, dynamic> json) => Tip(
        id: json['id'] as int,
        title: json['title'] as String,
        header: json['header'] as String,
        body: json['body'] as String,
        status: json['status'] as bool,
        type: TipType.fromValue(json['type'] as int),
        submittedOn: DateTime.parse(json['submitted_on'] as String),
        submittedBy: json['submitted_by'] as int?,
        approvedOn: json['approved_on'] != null
            ? DateTime.parse(json['approved_on'] as String)
            : null,
        approvedBy: json['approved_by'] as int?,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        lastUpdatedBy: json['last_updated_by'] as int?,
      );
}
