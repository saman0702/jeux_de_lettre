import '../../../core/network/api_client.dart';
import 'room_models.dart';

/// Un salon gardé : ouvert en ce moment ou fermé, en attente d'être rouvert.
class SavedRoomSummary {
  const SavedRoomSummary({
    required this.code,
    required this.public,
    required this.creator,
    this.creatorId,
    required this.members,
    required this.mine,
    required this.open,
    required this.playersNow,
    required this.format,
    required this.lastActivity,
  });

  factory SavedRoomSummary.fromJson(Map<String, dynamic> json) =>
      SavedRoomSummary(
        code: json['code'] as String,
        public: json['public'] as bool? ?? false,
        creator: json['creator'] as String? ?? '',
        creatorId: json['creator_id'] as String?,
        members: json['members'] as int? ?? 0,
        mine: json['mine'] as bool? ?? false,
        open: json['open'] as bool? ?? false,
        playersNow: json['players_now'] as int? ?? 0,
        format: RoomFormat.values.byName(json['format'] as String? ?? 'rounds'),
        lastActivity: DateTime.parse(json['last_activity_at'] as String),
      );

  final String code;
  final bool public;
  final String creator;

  /// Le créateur, seul à pouvoir supprimer le salon.
  final String? creatorId;

  /// Joueurs déjà passés par le salon.
  final int members;

  /// Le joueur y est déjà allé.
  final bool mine;

  /// Des joueurs sont dedans en ce moment.
  final bool open;
  final int playersNow;
  final RoomFormat format;
  final DateTime lastActivity;
}

/// Une partie jouée dans le salon : classement final.
class RoomGameSummary {
  const RoomGameSummary({
    required this.finishedAt,
    required this.format,
    required this.rounds,
    required this.ranking,
  });

  factory RoomGameSummary.fromJson(Map<String, dynamic> json) =>
      RoomGameSummary(
        finishedAt: DateTime.parse(json['finished_at'] as String),
        format: RoomFormat.values.byName(json['format'] as String? ?? 'rounds'),
        rounds: json['rounds'] as int? ?? 0,
        ranking: [
          for (final p in (json['ranking'] as List?) ?? const [])
            (
              clientId: (p as Map)['client_id'] as String,
              nickname: p['nickname'] as String,
              score: p['score'] as int? ?? 0,
              bot: p['bot'] as bool? ?? false,
            ),
        ],
      );

  final DateTime finishedAt;
  final RoomFormat format;
  final int rounds;
  final List<({String clientId, String nickname, int score, bool bot})> ranking;
}

/// Historique d'un salon : parties, conversation de groupe, conversations
/// privées du joueur.
class RoomHistory {
  const RoomHistory({
    required this.room,
    required this.games,
    required this.group,
    required this.private,
  });

  factory RoomHistory.fromJson(Map<String, dynamic> json) => RoomHistory(
    room: SavedRoomSummary.fromJson(json['room'] as Map<String, dynamic>),
    games: [
      for (final g in (json['games'] as List?) ?? const [])
        RoomGameSummary.fromJson(g as Map<String, dynamic>),
    ],
    group: [
      for (final m in (json['group'] as List?) ?? const [])
        RoomChatMessage.fromJson(m as Map<String, dynamic>),
    ],
    private: [
      for (final m in (json['private'] as List?) ?? const [])
        RoomChatMessage.fromJson(m as Map<String, dynamic>),
    ],
  );

  final SavedRoomSummary room;
  final List<RoomGameSummary> games;
  final List<RoomChatMessage> group;
  final List<RoomChatMessage> private;

  /// Conversations privées regroupées par interlocuteur : id -> (pseudo,
  /// messages), la plus récente d'abord.
  List<({String otherId, String otherName, List<RoomChatMessage> messages})>
  conversations(String me) {
    final byOther = <String, List<RoomChatMessage>>{};
    final names = <String, String>{};
    for (final m in private) {
      final other = m.clientId == me ? m.to! : m.clientId;
      (byOther[other] ??= []).add(m);
      if (m.clientId != me) names[other] = m.nickname;
    }
    final list = [
      for (final e in byOther.entries)
        (otherId: e.key, otherName: names[e.key] ?? '?', messages: e.value),
    ];
    list.sort(
      (a, b) => (b.messages.last.at ?? DateTime(0)).compareTo(
        a.messages.last.at ?? DateTime(0),
      ),
    );
    return list;
  }
}

/// Salons gardés sur le serveur.
class SavedRoomsApi {
  SavedRoomsApi(this._api, this.clientId);

  final ApiClient _api;
  final String clientId;

  Future<List<SavedRoomSummary>> mine() async => [
    for (final r in await _api.getJsonList(
      '/api/v1/rooms/mine?client_id=$clientId',
    ))
      SavedRoomSummary.fromJson(r as Map<String, dynamic>),
  ];

  /// Toutes langues confondues : chacun joue dans la sienne.
  Future<List<SavedRoomSummary>> public() async => [
    for (final r in await _api.getJsonList(
      '/api/v1/rooms/public?client_id=$clientId',
    ))
      SavedRoomSummary.fromJson(r as Map<String, dynamic>),
  ];

  /// Le créateur supprime son salon (parties et conversations comprises).
  Future<void> delete(String code) =>
      _api.deleteJson('/api/v1/rooms/$code?client_id=$clientId');

  Future<RoomHistory> history(String code) async => RoomHistory.fromJson(
    await _api.getJson('/api/v1/rooms/$code/history?client_id=$clientId'),
  );
}
