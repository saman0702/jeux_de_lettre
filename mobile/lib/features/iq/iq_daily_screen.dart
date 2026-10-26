import 'package:flutter/material.dart';

import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import 'iq_models.dart';
import 'iq_solo_screen.dart';

/// Ligne du classement du défi du jour.
class IqDailyRow {
  const IqDailyRow({
    required this.rank,
    required this.clientId,
    required this.nickname,
    required this.score,
    required this.correct,
    this.prize = 0,
  });

  factory IqDailyRow.fromJson(Map<String, dynamic> json) => IqDailyRow(
    rank: json['rank'] as int,
    clientId: json['client_id'] as String,
    nickname: json['nickname'] as String,
    score: json['score'] as int,
    correct: json['correct'] as int,
    prize: json['prize'] as int? ?? 0,
  );

  final int rank;
  final String clientId;
  final String nickname;
  final int score;
  final int correct;
  final int prize;
}

/// Défi QI du jour : les mêmes 10 énigmes pour tous, une tentative par jour,
/// classement et podium récompensé en pièces.
class IqDailyScreen extends StatefulWidget {
  const IqDailyScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<IqDailyScreen> createState() => _IqDailyScreenState();
}

class _IqDailyScreenState extends State<IqDailyScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  bool _loading = true;
  bool _played = false;
  IqDailyRow? _me;
  List<IqDailyRow> _top = const [];
  List<IqDailyRow> _yesterday = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final online = OnlineScope.of(context);
    setState(() => _loading = true);
    try {
      final board = await _api.getJson(
        '/api/v1/iq/daily/leaderboard?client_id=${online.clientId}',
      );
      if (!mounted) return;
      List<IqDailyRow> rows(Object? raw) => [
        for (final r in (raw as List?) ?? const [])
          IqDailyRow.fromJson(r as Map<String, dynamic>),
      ];
      setState(() {
        _played = board['played'] as bool? ?? false;
        _me = board['me'] == null
            ? null
            : IqDailyRow.fromJson(board['me'] as Map<String, dynamic>);
        _top = rows(board['top']);
        _yesterday = rows(board['yesterday']);
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code;
          _loading = false;
        });
      }
    }
  }

  Future<void> _play() async {
    await Navigator.of(context).push(
      PopRoute(
        builder: (_) => IqSoloScreen(
          rounds: 10,
          duration: 30,
          difficulty: Difficulty.normal,
          scoring: const IqScoring(),
          apiClient: _api,
          daily: true,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myId = OnlineScope.of(context).clientId;
    return Scaffold(
      body: GameBackground(
        theme: BackgroundTheme.iq,
        child: SafeArea(
          child: FloatingBarsLayout(
            header: OnlineHeader(
              title: l10n.iqDailyTitle,
              onBack: () => Navigator.of(context).pop(),
            ),
            children: [
              GameCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const GameIcon(
                      GameIconKind.trophy,
                      size: 40,
                      color: AppColors.orange,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.iqDailyInfo,
                      textAlign: TextAlign.center,
                      style: fredoka(size: 15, color: AppColors.ink),
                    ),
                    const SizedBox(height: 12),
                    if (_me != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.iqDailyRank(_me!.rank),
                          key: const Key('iq_daily_rank'),
                          style: gameFont(size: 20, color: AppColors.purple),
                        ),
                      ),
                    if (_played)
                      Text(
                        l10n.iqDailyDone,
                        key: const Key('iq_daily_done'),
                        textAlign: TextAlign.center,
                        style: fredoka(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      )
                    else
                      CandyButton(
                        key: const Key('iq_daily_play'),
                        label: l10n.iqDailyPlay,
                        icon: Icons.play_arrow_rounded,
                        color: AppColors.green,
                        textColor: AppColors.white,
                        loading: _loading,
                        onPressed: _error == null ? _play : null,
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    errorMessage(l10n, _error!),
                    textAlign: TextAlign.center,
                    style: fredoka(size: 15, color: AppColors.white),
                  ),
                ),
              _title(l10n.iqDailyLeaderboard),
              if (_top.isEmpty && !_loading)
                Text(
                  l10n.iqDailyEmpty,
                  textAlign: TextAlign.center,
                  style: fredoka(size: 15, color: AppColors.white),
                )
              else
                _board(_top, myId),
              if (_yesterday.isNotEmpty) ...[
                _title(l10n.iqDailyYesterday),
                _board(_yesterday, myId, prizes: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(text, style: gameFont(size: 19, color: AppColors.white)),
  );

  Widget _board(List<IqDailyRow> rows, String myId, {bool prizes = false}) =>
      GameCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final row in rows)
              Container(
                key: Key('iq_daily_row_${row.clientId}'),
                color: row.clientId == myId
                    ? AppColors.yellow.withValues(alpha: 0.25)
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${row.rank}',
                        style: gameFont(size: 17, color: AppColors.purple),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: fredoka(size: 15, weight: FontWeight.w600),
                      ),
                    ),
                    if (prizes && row.prize > 0) ...[
                      const GameIcon(GameIconKind.coin, size: 18),
                      Text(
                        ' +${row.prize}  ',
                        style: gameFont(size: 14, color: AppColors.orange),
                      ),
                    ],
                    Text(
                      '${row.score} pts',
                      style: gameFont(size: 15, color: AppColors.green),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
