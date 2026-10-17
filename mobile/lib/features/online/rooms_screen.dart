import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../animations/bounce_in.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/scroll_under_bars.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/labels.dart';
import 'create_room_screen.dart';
import 'data/room_models.dart';
import 'online_controller.dart';
import 'room_screen.dart';
import 'widgets/online_counter.dart';
import 'widgets/online_header.dart';
import 'widgets/player_avatar.dart';
import '../../core/widgets/game_icon.dart';

/// Salons publics ouverts, avec la création d'une salle ou l'accès par code.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late OnlineController _online;
  late String _language;
  StreamSubscription<String>? _errors;
  bool _watching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _online = OnlineScope.of(context);
    _language = Localizations.localeOf(context).languageCode;
    if (!_watching) {
      _watching = true;
      _online.watchRooms(_language);
      _online.client.addListener(_rewatch);
      _errors = _online.errors.listen(_showError);
    }
  }

  /// L'abonnement est perdu avec la connexion : on le renouvelle à la
  /// reconnexion.
  void _rewatch() {
    if (_online.isOnline) _online.watchRooms(_language);
  }

  void _showError(String code) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage(AppLocalizations.of(context), code))),
    );
  }

  @override
  void dispose() {
    _online.client.removeListener(_rewatch);
    _online.unwatchRooms();
    _errors?.cancel();
    super.dispose();
  }

  Future<void> _openRoom() async {
    await Navigator.of(context)
        .push(PopRoute(builder: (_) => const RoomScreen()));
    if (mounted) _online.watchRooms(_language);
  }

  void _join(String code) {
    _online.joinRoom(code);
    _openRoom();
  }

  Future<void> _askCode() async {
    final code = await askRoomCode(context);
    if (code != null) _join(code);
  }

  Future<void> _create() async {
    final created = await Navigator.of(context)
        .push<bool>(PopRoute(builder: (_) => const CreateRoomScreen()));
    if (created == true) await _openRoom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _online,
            // Seul l'en-tête reste en place : boutons et salons défilent
            // dessous, sans bord visible.
            builder: (context, _) => ScrollUnderBars(
              header: OnlineHeader(
                title: l10n.roomsTitle,
                onBack: () => Navigator.of(context).pop(),
                trailing: const OnlineCounter(),
              ),
              builder: (context, padding) => ListView(
                padding: padding.copyWith(bottom: padding.bottom + 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CandyButton(
                          label: l10n.createRoom,
                          icon: Icons.add_rounded,
                          onPressed: _online.isOnline ? _create : null,
                        ),
                        const SizedBox(height: 12),
                        CandyButton(
                          label: l10n.joinWithCode,
                          icon: Icons.vpn_key_rounded,
                          color: AppColors.white,
                          height: 54,
                          fontSize: 19,
                          onPressed: _online.isOnline ? _askCode : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                    child: Text(
                      l10n.publicRoomsTitle,
                      style: fredoka(
                        size: 20,
                        weight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  if (_online.rooms.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const GameIconBadge(
                              GameIconKind.empty,
                              color: AppColors.purpleLight,
                              size: 72,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noPublicRooms,
                              textAlign: TextAlign.center,
                              style: fredoka(
                                size: 17,
                                color: AppColors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final room in _online.rooms)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: BounceIn(
                          key: ValueKey(room.code),
                          from: 0.8,
                          child: _RoomTile(
                            room: room,
                            onTap: () => _join(room.code),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap});

  final RoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = room.quick ? l10n.modeQuickMatch : l10n.roomOf(room.host);

    Widget chip(String text) => Container(
      margin: const EdgeInsets.only(right: 6, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: fredoka(
          size: 13,
          weight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: GameCard(
        child: Row(
          children: [
            if (room.quick)
              const GameIconBadge(
                GameIconKind.bolt,
                color: AppColors.orange,
                size: 48,
              )
            else
              PlayerAvatar(nickname: room.host, seed: room.code, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: fredoka(size: 18, weight: FontWeight.w700),
                  ),
                  if (room.nicknames.isNotEmpty)
                    Text(
                      room.nicknames.join(', '),
                      key: ValueKey('with_${room.code}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: fredoka(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  Wrap(
                    children: [
                      chip(l10n.roundsCount(room.rounds)),
                      chip(l10n.secondsShort(room.roundDuration)),
                      chip(room.language.toUpperCase()),
                      if (room.format == RoomFormat.elimination)
                        chip(l10n.formatElimination),
                      if (room.kind == RoomKind.bet)
                        Container(
                          margin: const EdgeInsets.only(right: 6, top: 6),
                          padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const GameIcon(GameIconKind.coin, size: 16),
                              const SizedBox(width: 3),
                              Text(
                                l10n.stakeShort(room.stake),
                                style: fredoka(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon(GameIconKind.person, size: 18),
                  const SizedBox(width: 3),
                  Text(
                    l10n.playersCount(room.players, room.maxPlayers),
                    style: fredoka(
                      size: 15,
                      weight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Demande le code d'une salle ; null si le joueur annule.
Future<String?> askRoomCode(BuildContext context) async {
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const JoinCodeDialog(),
  );
  return code == null || code.isEmpty ? null : code;
}

class JoinCodeDialog extends StatefulWidget {
  const JoinCodeDialog();

  @override
  State<JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends State<JoinCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.length == 5) Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameIconBadge(
              GameIconKind.key,
              color: AppColors.yellow,
              size: 60,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.joinCodeTitle,
              style: fredoka(size: 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('code_field'),
              controller: _controller,
              autofocus: true,
              maxLength: 5,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                TextInputFormatter.withFunction(
                  (_, value) => value.copyWith(text: value.text.toUpperCase()),
                ),
              ],
              onSubmitted: (_) => _submit(),
              style: fredoka(
                size: 32,
                weight: FontWeight.w700,
              ).copyWith(letterSpacing: 8),
              decoration: const InputDecoration(
                fillColor: AppColors.cloud,
                counterText: '',
                hintText: 'X7K92',
              ),
            ),
            const SizedBox(height: 16),
            CandyButton(
              label: l10n.join,
              onPressed: _submit,
              color: AppColors.green,
              textColor: AppColors.white,
              height: 56,
              fontSize: 19,
            ),
          ],
        ),
      ),
    );
  }
}
