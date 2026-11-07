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

/// ACAPS risk categories, exactly as in the Risk Radar export (and on the
/// ACAPS website). Each risk carries ACAPS's own values; none are invented.
const riskTypes = [
  'New emerging risk',
  'Marked deterioration in an existing crisis',
  'Future impact of a hazard which has already taken place',
];

const priorityNeeds = [
  'Food security',
  'Protection',
  'Livelihoods',
  'Health',
  'WASH',
  'Displacement',
  'Humanitarian access',
  'Shelter',
  'Education',
  'Nutrition',
];

/// Expected exposure bands (people who may need additional assistance), smallest first.
const exposureBands = ['<20,000', '20,000-100,000', '100,000-250,000', '250,000-500,000', '>500,000'];

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

  /// ISO 3166-1 alpha-3 code(s), as in the Risk Radar export (e.g. "TCD").
  final String iso;
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
    this.iso = '',
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
      iso: f('ISO'),
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

  /// One record of the ACAPS API `risk-radar/risk-radar/` endpoint. Field
  /// names differ from the export (snake_case, lists for countries), but
  /// `triggers_summary` uses the same "Trigger ID: / Title:" format.
  /// Marked [custom] so it is saved on the device like a risk made in the app.
  ///
  /// Mapping, API field -> our field (the CSV column is in brackets):
  ///   risk_id                    -> id            (Risk ID)
  ///   risk_title                 -> title         (Risk Title)
  ///   risk_type                  -> type          (Risk Type)
  ///   iso3   ["TCD", "SDN"]      -> iso "TCD, SDN"        (ISO)
  ///   country ["Chad", "Sudan"]  -> country "Chad, Sudan" (Country)
  ///   probability "High"         -> probabilityIdx 3 (0 = Very low ... 4 = Very high)
  ///   impact "4"                 -> impact 4
  ///   risk_level / risk_trend / status  -> level / trend / status
  ///   hazard_ + impact_materialisation_description -> materialisation
  ///   triggers_summary           -> triggers (parsed like the CSV column)
  /// Using the same parsers as the CSV (parseLevel5, parseTriggers,
  /// stripMarkdownLinks) means an imported risk looks exactly like one from
  /// the export everywhere in the app.
  factory Risk.fromApi(Map<String, dynamic> m) {
    // Reads a field as clean text: null -> "", lists -> "a, b", trimmed.
    String f(String k) {
      final v = m[k];
      if (v == null) return '';
      if (v is List) return v.map((x) => '$x'.trim()).where((x) => x.isNotEmpty).join(', ');
      return '$v'.trim();
    }

    // "What happened": the API splits it into hazard and impact; we show both
    // as two paragraphs, like Risk.fromRow does for the CSV.
    final mat = [f('hazard_materialisation_description'), f('impact_materialisation_description')]
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    // The API also has a plain `triggers` list (ids only); the summary has the
    // titles and descriptions the survey needs.
    final triggers = m['triggers_summary'];
    return Risk(
      custom: true,
      id: f('risk_id'),
      title: f('risk_title'),
      type: f('risk_type'),
      country: f('country'),
      iso: f('iso3'),
      rationale: stripMarkdownLinks(f('rationale')),
      probabilityIdx: parseLevel5(f('probability')),
      impact: int.tryParse(f('impact')),
      level: f('risk_level'),
      trend: f('risk_trend'),
      status: f('status'),
      exposure: f('expected_exposure'),
      needs: f('expected_priority_needs'),
      materialisation: stripMarkdownLinks(mat),
      triggers: parseTriggers(triggers is String ? triggers : ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'country': country,
        'iso': iso,
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
        iso: (m['iso'] as String?) ?? '',
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

  /// Same risk with a new status (and what happened), e.g. after a Risk Radar sync.
  ///
  /// [Risk] is immutable (all fields final), so instead of changing a risk we
  /// build a copy with the new values. Everything else, including the id, stays
  /// the same, so answers and comments stay linked to the risk.
  Risk withStatus(String status, {String? materialisation}) => Risk(
        custom: custom,
        id: id,
        title: title,
        type: type,
        country: country,
        iso: iso,
        rationale: rationale,
        probabilityIdx: probabilityIdx,
        impact: impact,
        level: level,
        trend: trend,
        status: status,
        exposure: exposure,
        needs: needs,
        materialisation: materialisation ?? this.materialisation,
        triggers: triggers,
      );

  bool get isActive => status.toLowerCase() == 'active';
  bool get materialised => status.toLowerCase() == 'materialised';
  bool get isResolved =>
      materialised || status.toLowerCase() == 'not materialised';

  /// Imported from ACAPS's earlier risk list (IDs below R1000). The brief
  /// warns these "resolve over much longer periods than recent ones", so
  /// their scores are not true 6-month forecasts: labelled as indicative.
  bool get fromEarlierList => !custom && (int.tryParse(id.replaceAll(RegExp('[^0-9]'), '')) ?? 1000) < 1000;

  bool inCountry(String c) =>
      country.split(',').map((s) => s.trim()).contains(c);

  String get shortType => shortTypeOf(type);

  /// Short label for a risk type, for chips: "New risk", "Deterioration", "Hazard impact".
  static String shortTypeOf(String type) {
    final t = type.toLowerCase();
    if (t.startsWith('new')) return 'New risk';
    if (t.startsWith('marked')) return 'Deterioration';
    if (t.startsWith('future')) return 'Hazard impact';
    return type.isEmpty ? 'Risk' : type;
  }

  /// Expected priority needs as separate categories, in ACAPS's order.
  List<String> get needList {
    final given = needs.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
    return [...priorityNeeds.where(given.contains), ...given.where((s) => !priorityNeeds.contains(s))];
  }

  /// Position of the expected exposure in [exposureBands], or null if unknown.
  int? get exposureIdx {
    final i = exposureBands.indexOf(exposure.trim());
    return i < 0 ? null : i;
  }

  /// Everything a search should match: ID, title, countries and categories.
  String get searchText => '$id $title $country $type $needs $exposure'.toLowerCase();

  /// First paragraph of the rationale, trimmed for a card.
  String get summary {
    final p = rationale.split(RegExp(r'\n\s*\n')).first.trim();
    return p.length > 320 ? '${p.substring(0, 320).trimRight()}…' : p;
  }
}

/// A risk whose status in the ACAPS Risk Radar differs from the app's.
/// Produced by AppState.statusChanges, listed on the "Sync statuses" screen,
/// applied by AppState.applyStatusChanges.
class StatusChange {
  /// The risk as it is in the app now (so [from] is its current status).
  final Risk risk;

  /// The status in the Risk Radar: "Active", "Materialised" or "Not materialised".
  final String to;

  /// What happened, from the API (empty if it has no text).
  final String materialisation;
  const StatusChange(this.risk, this.to, this.materialisation);

  String get from => risk.status;
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

  /// Share of answers on the median step (0..1); 0 when the median is
  /// halfway between two steps.
  final double share;

  const GroupView._(this.n, this.median, this.low, this.high, this.share);

  static GroupView? of(Iterable<int> answers) {
    final xs = answers.toList()..sort();
    if (xs.isEmpty) return null;
    final n = xs.length;
    final median = n.isOdd ? xs[n ~/ 2].toDouble() : (xs[n ~/ 2 - 1] + xs[n ~/ 2]) / 2;
    final share = xs.where((x) => x == median).length / n;
    return GroupView._(n, median, xs[((n - 1) * 0.25).round()], xs[((n - 1) * 0.75).round()], share);
  }

  /// True when the median is a step on the scale (not halfway between two).
  bool get onStep => median == median.roundToDouble();

  /// The middle half of answers spans two or more steps: no trustworthy group
  /// answer. ACAPS's example: 1, 1, 5, 5 has a "medium" average but means
  /// nobody agrees. A split is information too: this part needs attention.
  bool get split => high - low >= 2;

  /// Short form for trends: "High", "Medium–High", or "split".
  String get short => split
      ? 'split'
      : onStep
          ? levelLabels[median.round() - 1]
          : '${levelLabels[median.floor() - 1]}–${levelLabels[median.ceil() - 1]}';

  /// Headline for a forecast: the group answer, or "opinions split".
  String get probabilityHeadline => split ? 'No clear group view: opinions split' : 'Group: $probability';

  /// Headline for "how bad": the group answer, or "opinions split".
  String get severityHeadline => split ? 'No clear group view: opinions split' : 'Group: $severity';

  /// "High (67–90%)", or "between Medium and High".
  String get probability => onStep
      ? probabilityText(median.round())
      : 'between ${levelLabels[median.floor() - 1]} and ${levelLabels[median.ceil() - 1]}';

  /// "4 of 5 (Severe)", or "between 3 and 4 of 5".
  String get severity => onStep
      ? '${median.round()} of 5 (${severityLabels[median.round() - 1]})'
      : 'between ${median.floor()} and ${median.ceil()} of 5';

  /// How far experts agree, in words. "Experts agree" only when nearly all
  /// (at least 3 in 4) gave the same answer.
  String spread(List<String> words) {
    if (split) return 'Opinions split: answers range from ${words[low - 1]} to ${words[high - 1]}';
    if (high == low) {
      return share >= 0.75 ? 'Experts agree: nearly all said ${words[low - 1]}' : 'Most experts said ${words[low - 1]}';
    }
    return 'Most experts between ${words[low - 1]} and ${words[high - 1]}';
  }
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

/// A single-use invite code: one per person, works once. Trust is checked
/// at the door (ACAPS knows whom it invited); inside, the expert chooses
/// their anonymity. So an invite records THAT it was used, never by which
/// account: otherwise a fully anonymous expert could be traced through it.
class Invite {
  final String code;

  /// Optional suggestion for the new expert's country (the demo invites have
  /// one); the expert chooses their countries when creating their profile.
  final String? country;

  /// Moderator who created it.
  final String createdBy;

  /// Their name, for codes listed from the server (real moderator accounts).
  final String? createdByName;
  final DateTime createdAt;

  /// Who it is for, so moderators can follow up. Moderators only.
  String note;
  DateTime? usedAt;
  bool revoked;

  Invite({
    required this.code,
    this.country,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.note = '',
    this.usedAt,
    this.revoked = false,
  });

  bool get used => usedAt != null;
  bool get open => !used && !revoked;

  Map<String, dynamic> toJson() => {
        'code': code,
        if (country != null) 'country': country,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'note': note,
        if (usedAt != null) 'used_at': usedAt!.toIso8601String(),
        'revoked': revoked,
      };

  factory Invite.fromJson(Map<String, dynamic> m) => Invite(
        code: m['code'] as String,
        country: m['country'] as String?,
        createdBy: m['created_by'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        note: (m['note'] as String?) ?? '',
        usedAt: m['used_at'] == null ? null : DateTime.parse(m['used_at'] as String),
        revoked: m['revoked'] == true,
      );
}

/// Result of checking a typed invite or referral code.
enum InviteStatus { ok, unknown, used, revoked, expired }

/// Someone joined with an expert's referral code. The joined account is
/// kept so the inviter can follow the colleague's progress (how many risks
/// answered) and, in the pilot, earn points after 3 answered risks. The
/// inviter only ever sees the stage: never the name, pseudonym, answers or
/// comments. New members are told this when they join.
class Referral {
  final String referrerId;
  final DateTime joinedAt;

  /// The account that joined (null for referrals saved before stages existed).
  final String? referredId;
  const Referral(this.referrerId, this.joinedAt, [this.referredId]);

  Map<String, dynamic> toJson() => {
        'referrer': referrerId,
        'at': joinedAt.toIso8601String(),
        if (referredId != null) 'referred': referredId,
      };

  factory Referral.fromJson(Map<String, dynamic> m) =>
      Referral(m['referrer'] as String, DateTime.parse(m['at'] as String), m['referred'] as String?);
}

/// How far a referred colleague has got.
enum ReferralStage { joined, firstRisk, threeRisks }

/// One dated forecast. Every time an expert answers (or changes their answer)
/// a check-in is added; none is ever overwritten, so ACAPS sees how the view
/// moves over time ("from a snapshot to a live picture").
class CheckIn {
  final int forecast;
  final DateTime at;
  const CheckIn(this.forecast, this.at);

  Map<String, dynamic> toJson() => {'forecast': forecast, 'at': at.toIso8601String()};

  factory CheckIn.fromJson(Map<String, dynamic> m) =>
      CheckIn((m['forecast'] as num).toInt(), DateTime.parse(m['at'] as String));
}

/// One expert's answers to one risk: ground truthing per trigger, plus one
/// forecast for the whole risk, with every earlier check-in kept.
class Response {
  final String expertId;
  final String riskId;

  /// Per trigger: agree, how bad, what's missing (not scored). Latest answer.
  final Map<String, ItemAnswer> items;

  /// "Will this risk materialise within 6 months?" on the ACAPS scale 1..5.
  /// The only scored answer: the latest check-in.
  final int? forecast;
  final DateTime answeredAt;
  final DateTime? editedAt;
  final bool simulated;

  /// Every forecast this expert gave on this risk, oldest first; the last
  /// one is [forecast].
  final List<CheckIn> history;

  /// Chosen for this risk; null = the default (anonymous).
  final Credit? credit;

  Response({
    required this.expertId,
    required this.riskId,
    required this.items,
    required this.forecast,
    required this.answeredAt,
    this.editedAt,
    this.simulated = false,
    this.credit,
    List<CheckIn>? history,
  }) : history = history ?? (forecast == null ? const [] : [CheckIn(forecast, editedAt ?? answeredAt)]);

  /// End of the 6-month window the forecast is about.
  DateTime get resolvesBy => answeredAt.add(forecastHorizon);

  /// The forecast this expert had given by [t] (their latest check-in on or
  /// before it), or null if they had not answered yet.
  int? forecastAt(DateTime t) => history.where((c) => !c.at.isAfter(t)).lastOrNull?.forecast;

  Map<String, dynamic> toJson() => {
        'expert': expertId,
        'risk': riskId,
        'items': {for (final e in items.entries) e.key: e.value.toJson()},
        if (forecast != null) 'forecast': forecast,
        'history': [for (final c in history) c.toJson()],
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
      // Saved before check-ins were kept: the one answer becomes the history.
      history: m['history'] == null
          ? null
          : [for (final c in m['history'] as List) CheckIn.fromJson((c as Map).cast<String, dynamic>())],
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
