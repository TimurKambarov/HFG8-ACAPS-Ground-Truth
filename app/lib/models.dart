/// ACAPS 5-point probability scale. Experts forecast on the same scale as
/// ACAPS, so the two can be compared and scored the same way.
const levelLabels = ['Very low', 'Low', 'Medium', 'High', 'Very high'];

/// What each step means, from the ACAPS risk methodology (references/acaps-risk-methodology.pdf).
const probabilityRanges = ['<10%', '10–33%', '34–66%', '67–90%', '>90%'];

/// Probability used to score each step: the middle of its range, rounded.
const probabilityScores = [0.05, 0.20, 0.50, 0.80, 0.95];

/// "High (67–90%)" for a value on the 1-5 scale.
String probabilityText(int v) => '${levelLabels[v - 1]} (${probabilityRanges[v - 1]})';

/// Forecast horizon from the challenge brief.
const forecastHorizon = Duration(days: 182);

int? parseLevel5(String s) {
  switch (s.trim().toLowerCase()) {
    case 'very low':
      return 0;
    case 'low':
      return 1;
    case 'medium':
      return 2;
    case 'high':
      return 3;
    case 'very high':
      return 4;
  }
  return null;
}

/// "[ACLED 08/04/2026](https://...)" -> "ACLED 08/04/2026"
String stripMarkdownLinks(String s) => s
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
    .replaceAll(r'\)', ')')
    .trim();

class Trigger {
  final String id;
  final String title;
  final String description;
  final int? completion;

  const Trigger({
    required this.id,
    required this.title,
    required this.description,
    this.completion,
  });
}

/// Parses the structured "Trigger ID: / Title: / Description:" field.
List<Trigger> parseTriggers(String raw) {
  if (!raw.contains('Trigger ID:')) return const [];
  final out = <Trigger>[];
  for (final chunk in raw.split('Trigger ID:').skip(1)) {
    final id = chunk.split('\n').first.trim();
    final title =
        RegExp(r'Title:[ \t]*(.*)').firstMatch(chunk)?.group(1)?.trim() ?? '';
    var desc = RegExp(
                r'Description:\s*([\s\S]*?)(?:\n\s*Sources:|\n\s*Completion rate:|$)')
            .firstMatch(chunk)
            ?.group(1) ??
        '';
    desc = desc.trim();
    while (desc.startsWith(':')) {
      desc = desc.substring(1).trim();
    }
    final completion =
        RegExp(r'Completion rate:\s*(\d+)%').firstMatch(chunk)?.group(1);
    out.add(Trigger(
      id: id,
      title: title.isEmpty ? id : title,
      description: stripMarkdownLinks(desc),
      completion: completion == null ? null : int.parse(completion),
    ));
  }
  return out;
}

class Risk {
  final String id;
  final String title;
  final String type;
  final String country;
  final String rationale;
  final int? probabilityIdx;
  final int? impact;
  final String level;
  final String trend;
  final String status;
  final String exposure;
  final String needs;
  final String materialisation;
  final List<Trigger> triggers;

  /// Created by an ACAPS moderator in the app (not from the Risk Radar export).
  final bool custom;

  const Risk({
    this.custom = false,
    required this.id,
    required this.title,
    required this.type,
    required this.country,
    required this.rationale,
    required this.probabilityIdx,
    required this.impact,
    required this.level,
    required this.trend,
    required this.status,
    required this.exposure,
    required this.needs,
    required this.materialisation,
    required this.triggers,
  });

  factory Risk.fromRow(Map<String, String> m) {
    String f(String k) => (m[k] ?? '').trim();
    final mat = [f('Hazard materialisation'), f('Impact materialisation description')]
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    return Risk(
      id: f('Risk ID'),
      title: f('Risk Title'),
      type: f('Risk Type'),
      country: f('Country'),
      rationale: stripMarkdownLinks(f('Rationale')),
      probabilityIdx: parseLevel5(f('Probability')),
      impact: int.tryParse(f('Impact')),
      level: f('Risk Level'),
      trend: f('Risk trend'),
      status: f('Status'),
      exposure: f('Expected exposure'),
      needs: f('Expected priority needs'),
      materialisation: stripMarkdownLinks(mat),
      triggers: parseTriggers(m['Triggers'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'country': country,
        'rationale': rationale,
        'probability': probabilityIdx,
        'impact': impact,
        'level': level,
        'trend': trend,
        'status': status,
        'exposure': exposure,
        'needs': needs,
        'materialisation': materialisation,
        'triggers': [
          for (final t in triggers) {'id': t.id, 'title': t.title, 'description': t.description},
        ],
      };

  factory Risk.fromJson(Map<String, dynamic> m) => Risk(
        custom: true,
        id: m['id'] as String,
        title: m['title'] as String,
        type: (m['type'] as String?) ?? '',
        country: m['country'] as String,
        rationale: (m['rationale'] as String?) ?? '',
        probabilityIdx: (m['probability'] as num?)?.toInt(),
        impact: (m['impact'] as num?)?.toInt(),
        level: (m['level'] as String?) ?? '',
        trend: (m['trend'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'Active',
        exposure: (m['exposure'] as String?) ?? '',
        needs: (m['needs'] as String?) ?? '',
        materialisation: (m['materialisation'] as String?) ?? '',
        triggers: [
          for (final t in (m['triggers'] as List? ?? const []))
            Trigger(id: t['id'] as String, title: t['title'] as String, description: (t['description'] as String?) ?? ''),
        ],
      );

  bool get isActive => status.toLowerCase() == 'active';
  bool get materialised => status.toLowerCase() == 'materialised';
  bool get isResolved =>
      materialised || status.toLowerCase() == 'not materialised';

  bool inCountry(String c) =>
      country.split(',').map((s) => s.trim()).contains(c);

  String get shortType {
    final t = type.toLowerCase();
    if (t.startsWith('new')) return 'New risk';
    if (t.startsWith('marked')) return 'Deterioration';
    if (t.startsWith('future')) return 'Hazard impact';
    return type.isEmpty ? 'Risk' : type;
  }

  /// First paragraph of the rationale, trimmed for a card.
  String get summary {
    final p = rationale.split(RegExp(r'\n\s*\n')).first.trim();
    return p.length > 320 ? '${p.substring(0, 320).trimRight()}…' : p;
  }
}

/// Hand-written one-line summaries for demo risks; others fall back to the title.
const _oneLiners = {
  'R1043': 'The war in Sudan may spill across the border into eastern Chad.',
};

extension RiskSurvey on Risk {
  String get oneLiner => _oneLiners[id] ?? title;

  /// One survey screen per trigger (max 3), or one screen for the risk itself.
  List<SurveyItem> get surveyItems => triggers.isEmpty
      ? [SurveyItem(id: 'risk', title: 'The risk as a whole', description: summary)]
      : [
          for (final t in triggers.take(3))
            SurveyItem(id: t.id, title: t.title, description: t.description, completion: t.completion),
        ];

  /// ACAPS probability on the 1-5 forecast scale.
  int? get acapsLikelihood => probabilityIdx == null ? null : probabilityIdx! + 1;
}

class SurveyItem {
  final String id;
  final String title;
  final String description;
  final int? completion;

  const SurveyItem({required this.id, required this.title, required this.description, this.completion});
}

enum Agreement { yes, partly, no }

extension AgreementText on Agreement {
  String get label => switch (this) {
        Agreement.yes => 'Yes',
        Agreement.partly => 'Partly',
        Agreement.no => 'No',
      };
}

const severityLabels = ['Minor', 'Moderate', 'Serious', 'Severe', 'Critical'];

/// The group's answer on a 1-5 scale, Delphi-style: the median, and the
/// range the middle half of answers falls in. The median is robust to one
/// outlier in a small panel (5-10 experts), and the range shows how far
/// experts agree, so the group view does not hide disagreement.
class GroupView {
  final int n;
  final double median;

  /// Middle half of answers (interquartile range), as scale steps.
  final int low, high;

  const GroupView._(this.n, this.median, this.low, this.high);

  static GroupView? of(Iterable<int> answers) {
    final xs = answers.toList()..sort();
    if (xs.isEmpty) return null;
    final n = xs.length;
    final median = n.isOdd ? xs[n ~/ 2].toDouble() : (xs[n ~/ 2 - 1] + xs[n ~/ 2]) / 2;
    return GroupView._(n, median, xs[((n - 1) * 0.25).round()], xs[((n - 1) * 0.75).round()]);
  }

  /// True when the median is a step on the scale (not halfway between two).
  bool get onStep => median == median.roundToDouble();

  /// "High (67–90%)", or "between Medium and High".
  String get probability => onStep
      ? probabilityText(median.round())
      : 'between ${levelLabels[median.floor() - 1]} and ${levelLabels[median.ceil() - 1]}';

  /// "4 of 5 (Severe)", or "between 3 and 4 of 5".
  String get severity => onStep
      ? '${median.round()} of 5 (${severityLabels[median.round() - 1]})'
      : 'between ${median.floor()} and ${median.ceil()} of 5';

  /// How far experts agree, in words.
  String spread(List<String> words) => high - low == 0
      ? 'Experts agree: most said ${words[low - 1]}'
      : high - low == 1
          ? 'Most experts between ${words[low - 1]} and ${words[high - 1]}'
          : 'Opinions split: most experts between ${words[low - 1]} and ${words[high - 1]}';
}

/// Ground-truthing answers on one trigger screen. Not scored: whether a
/// trigger "happened" is never recorded, only whether the whole risk did.
class ItemAnswer {
  final Agreement agree;

  /// 1..5
  final int severity;
  final String missing;

  const ItemAnswer({required this.agree, required this.severity, this.missing = ''});

  Map<String, dynamic> toJson() => {'agree': agree.index, 'severity': severity, 'missing': missing};

  factory ItemAnswer.fromJson(Map<String, dynamic> m) => ItemAnswer(
        agree: Agreement.values[(m['agree'] as num).toInt()],
        severity: (m['severity'] as num).toInt(),
        missing: (m['missing'] as String?) ?? '',
      );
}

/// How an expert wants to be credited when ACAPS publishes a risk they
/// answered. Credits list contributors; they never sit next to an answer.
enum Credit { realName, pseudonym, anonymous }

extension CreditText on Credit {
  String get label => switch (this) {
        Credit.realName => 'Real name',
        Credit.pseudonym => 'Pseudonym',
        Credit.anonymous => 'Anonymous',
      };
}

/// One expert's answers to one risk: ground truthing per trigger, plus one
/// forecast for the whole risk.
class Response {
  final String expertId;
  final String riskId;

  /// Per trigger: agree, how bad, what's missing (not scored).
  final Map<String, ItemAnswer> items;

  /// "Will this risk materialise within 6 months?" on the ACAPS scale 1..5.
  /// The only scored answer.
  final int? forecast;
  final DateTime answeredAt;
  final DateTime? editedAt;
  final bool simulated;

  /// Chosen for this risk; null = the default from the expert's profile.
  final Credit? credit;

  const Response({
    required this.expertId,
    required this.riskId,
    required this.items,
    required this.forecast,
    required this.answeredAt,
    this.editedAt,
    this.simulated = false,
    this.credit,
  });

  /// End of the 6-month window the forecast is about.
  DateTime get resolvesBy => answeredAt.add(forecastHorizon);

  Map<String, dynamic> toJson() => {
        'expert': expertId,
        'risk': riskId,
        'items': {for (final e in items.entries) e.key: e.value.toJson()},
        if (forecast != null) 'forecast': forecast,
        'at': answeredAt.toIso8601String(),
        if (editedAt != null) 'edited': editedAt!.toIso8601String(),
        if (credit != null) 'credit': credit!.name,
      };

  factory Response.fromJson(Map<String, dynamic> m) {
    final rawItems = (m['items'] as Map).cast<String, dynamic>();
    // Answers saved before the single forecast existed had a likelihood per
    // trigger: their rounded average becomes the forecast.
    final old = [for (final v in rawItems.values) ((v as Map)['likelihood'] as num?)?.toDouble()].whereType<double>().toList();
    final migrated = old.isEmpty ? null : (old.reduce((a, b) => a + b) / old.length).round().clamp(1, 5);
    return Response(
      expertId: m['expert'] as String,
      riskId: m['risk'] as String,
      items: {
        for (final e in rawItems.entries) e.key: ItemAnswer.fromJson((e.value as Map).cast<String, dynamic>()),
      },
      forecast: (m['forecast'] as num?)?.toInt() ?? migrated,
      answeredAt: DateTime.parse(m['at'] as String),
      editedAt: m['edited'] == null ? null : DateTime.parse(m['edited'] as String),
      credit: Credit.values.where((c) => c.name == m['credit']).firstOrNull,
    );
  }
}

/// A "what is ACAPS missing?" contribution.
class Comment {
  final String id;
  final String riskId;
  final String itemId;
  final String authorId;
  String text;
  bool useful;
  String? usedInRiskId;

  /// A moderator has looked at it (marking useful / used also counts).
  bool reviewed;

  /// Moderator account behind each action (null = nobody, or before accounts).
  String? reviewedBy;
  String? usefulBy;
  String? usedBy;
  final Set<String> agreeIds;
  final Set<String> disagreeIds;

  Comment({
    required this.id,
    required this.riskId,
    required this.itemId,
    required this.authorId,
    required this.text,
    this.useful = false,
    this.usedInRiskId,
    this.reviewed = false,
    this.reviewedBy,
    this.usefulBy,
    this.usedBy,
    Set<String>? agreeIds,
    Set<String>? disagreeIds,
  })  : agreeIds = agreeIds ?? {},
        disagreeIds = disagreeIds ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'risk': riskId,
        'item': itemId,
        'author': authorId,
        'text': text,
        'useful': useful,
        'used_in': usedInRiskId,
        'reviewed': reviewed,
        if (reviewedBy != null) 'reviewed_by': reviewedBy,
        if (usefulBy != null) 'useful_by': usefulBy,
        if (usedBy != null) 'used_by': usedBy,
        'agree': agreeIds.toList(),
        'disagree': disagreeIds.toList(),
      };

  bool get needsReview => !reviewed && !useful && usedInRiskId == null;

  factory Comment.fromJson(Map<String, dynamic> m) => Comment(
        id: m['id'] as String,
        riskId: m['risk'] as String,
        itemId: m['item'] as String,
        authorId: m['author'] as String,
        text: m['text'] as String,
        useful: m['useful'] == true,
        usedInRiskId: m['used_in'] as String?,
        reviewed: m['reviewed'] == true,
        reviewedBy: m['reviewed_by'] as String?,
        usefulBy: m['useful_by'] as String?,
        usedBy: m['used_by'] as String?,
        agreeIds: {...((m['agree'] as List?) ?? const []).cast<String>()},
        disagreeIds: {...((m['disagree'] as List?) ?? const []).cast<String>()},
      );
}
