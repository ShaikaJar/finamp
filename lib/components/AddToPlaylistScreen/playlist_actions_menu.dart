import 'package:collection/collection.dart';
import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

import '../../models/jellyfin_models.dart';
import '../../services/favorite_provider.dart';
import '../../services/feedback_helper.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/theme_provider.dart';
import '../AlbumScreen/song_menu.dart';
import '../album_image.dart';
import '../global_snackbar.dart';
import '../themed_bottom_sheet.dart';
import 'add_to_playlist_list.dart';

const playlistActionsMenuRouteName = "/playlist-actions-menu";

Future<void> showPlaylistActionsMenu({
  required BuildContext context,
  required BaseItemDto item,
  required BaseItemDto? parentPlaylist,
  bool usePlayerTheme = false,
  bool confirmPlaylistRemoval = false,
  FinampTheme? themeProvider,
}) async {
  final isOffline = FinampSettingsHelper.finampSettings.isOffline;

  FeedbackHelper.feedback(FeedbackType.selection);

  await showThemedBottomSheet(
      context: context,
      item: item,
      routeName: playlistActionsMenuRouteName,
      minDraggableHeight: 0.2,
      buildSlivers: (context) {
        var themeColor = Theme.of(context).colorScheme.primary;
        var playlistsCallback = ValueNotifier<List<BaseItemDto>?>(null);

        final menuEntries = [
          SongInfo(
            item: item,
            useThemeImage: usePlayerTheme,
          ),
          const SizedBox(height: 10),
          Consumer(
            builder: (context, ref, child) {
              bool isFavorite =
                  ref.watch(isFavoriteProvider(item.id, DefaultValue(item)));
              return ToggleableListTile(
                title: AppLocalizations.of(context)!.favourites,
                leading: AspectRatio(
                  aspectRatio: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.3),
                    ),
                    child: const Center(
                      child: Icon(
                        TablerIcons.heart,
                        size: 36.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                positiveIcon: TablerIcons.heart_filled,
                negativeIcon: TablerIcons.heart,
                initialState: isFavorite,
                onToggle: (bool currentState) async {
                  return ref
                      .read(
                          isFavoriteProvider(item.id, DefaultValue()).notifier)
                      .updateFavorite(!isFavorite);
                },
                enabled: !isOffline,
              );
            },
          ),
          if (parentPlaylist != null)
            RemovablePlaylist(
              parentPlaylist: parentPlaylist,
              item: item,
              confirmPlaylistRemoval: confirmPlaylistRemoval,
              listenable: playlistsCallback,
            )
        ];

        var menu = [
          SliverStickyHeader(
            header: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).textTheme.bodySmall!.color!,
                      borderRadius: BorderRadius.circular(3.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                        AppLocalizations.of(context)!.addRemoveFromPlaylist,
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge!.color!,
                            fontSize: 18,
                            fontWeight: FontWeight.w400)),
                  ),
                ],
              ),
            ),
            sliver: MenuMask(
                height: 65.0,
                child: SliverList(
                    delegate: SliverChildListDelegate.fixed(
                  menuEntries,
                ))),
          ),
          SliverStickyHeader(
              header: Padding(
                padding: const EdgeInsets.only(
                    top: 24.0, bottom: 8.0, left: 16.0, right: 16.0),
                child: Text(AppLocalizations.of(context)!.addPlaylistSubheader,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              sliver: MenuMask(
                height: 55.0,
                child: AddToPlaylistList(
                  itemToAdd: item,
                  hiddenPlaylists:
                      parentPlaylist != null ? [parentPlaylist] : [],
                  playlistsCallback: playlistsCallback,
                ),
              )),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100.0))
        ];
        // TODO better estimate, how to deal with lag getting playlists?
        var stackHeight = MediaQuery.sizeOf(context).height * 0.9;
        return (stackHeight, menu);
      },
      usePlayerTheme: usePlayerTheme,
      themeProvider: themeProvider);
}

class RemovablePlaylist extends StatefulWidget {
  const RemovablePlaylist(
      {super.key,
      required this.parentPlaylist,
      required this.item,
      required this.confirmPlaylistRemoval,
      required this.listenable});

  final BaseItemDto parentPlaylist;
  final BaseItemDto item;
  final bool confirmPlaylistRemoval;
  final ValueNotifier<List<BaseItemDto>?> listenable;

  @override
  State<RemovablePlaylist> createState() => _RemovablePlaylistState();
}

class _RemovablePlaylistState extends State<RemovablePlaylist> {
  int _childCountOffset = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: widget.listenable,
        builder: (context, playlists, _) {
          var parent = playlists
                  ?.firstWhereOrNull((x) => x.id == widget.parentPlaylist.id) ??
              widget.parentPlaylist;
          return ToggleableListTile(
            title: parent.name ?? AppLocalizations.of(context)!.unknownName,
            subtitle: AppLocalizations.of(context)!
                .songCount(_childCountOffset + (parent.childCount ?? 0)),
            leading: AlbumImage(item: parent),
            positiveIcon: TablerIcons.circle_check_filled,
            negativeIcon: TablerIcons.circle_plus,
            initialState: true,
            onToggle: (bool currentState) async {
              if (currentState) {
                // part of playlist, remove
                bool removed = await removeFromPlaylist(
                    context, widget.item, parent,
                    confirm: widget.confirmPlaylistRemoval);
                if (removed) {
                  setState(() {
                    _childCountOffset--;
                  });
                }
                return !removed;
              } else {
                // add back to playlist
                bool added =
                    await addItemToPlaylist(context, widget.item, parent);
                if (added) {
                  setState(() {
                    _childCountOffset++;
                  });
                }
                return added;
              }
            },
            enabled: !FinampSettingsHelper.finampSettings.isOffline,
          );
        });
  }
}

class ToggleableListTile extends ConsumerStatefulWidget {
  const ToggleableListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.leading,
    required this.positiveIcon,
    required this.negativeIcon,
    required this.initialState,
    required this.onToggle,
    required this.enabled,
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final IconData positiveIcon;
  final IconData negativeIcon;
  final bool initialState;
  final Future<bool> Function(bool currentState) onToggle;
  final bool enabled;

  @override
  ConsumerState<ToggleableListTile> createState() => _ToggleableListTileState();
}

class _ToggleableListTileState extends ConsumerState<ToggleableListTile> {
  bool isLoading = false;
  bool currentState = false;

  @override
  void initState() {
    super.initState();
    currentState = widget.initialState;
  }

  @override
  Widget build(BuildContext context) {
    var themeColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding:
          const EdgeInsets.only(left: 12.0, right: 12.0, top: 4.0, bottom: 4.0),
      child: Container(
        decoration: ShapeDecoration(
          color: themeColor.withOpacity(currentState ? 0.3 : 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        child: ListTile(
          enableFeedback: true,
          enabled: widget.enabled,
          leading: widget.leading,
          title: Text(
            widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                SizedBox(
                  height: 48.0,
                  width: 16.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: VerticalDivider(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.5),
                      thickness: 1.5,
                      indent: 8.0,
                      endIndent: 8.0,
                      width: 1.0,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 12.0),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : Icon(
                          currentState == true
                              ? widget.positiveIcon
                              : widget.negativeIcon,
                          size: 36.0,
                          color: themeColor,
                        ),
                ),
              ]),
          onTap: () async {
            try {
              setState(() {
                isLoading = true;
              });
              final result = await widget.onToggle(currentState);
              FeedbackHelper.feedback(FeedbackType.success);
              setState(() {
                isLoading = false;
                currentState = result;
              });
            } catch (e) {
              setState(() {
                isLoading = false;
              });
              GlobalSnackbar.error(e);
            }
          },
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 0,
          // visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
        ),
      ),
    );
  }
}
