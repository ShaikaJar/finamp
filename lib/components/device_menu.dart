import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

showDeviceMenu(BuildContext context) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final sessions = await jellyfinApiHelper.getControllableSessions();
  final header = DeviceMenuHeader();
  var stackHeight = header.maxExtent + sessions.length * 56;
  await showThemedBottomSheet(
    context: context,
    item: BaseItemDto(id: 'asta', name: 'Test'),
    routeName: '/cast',
    themeProvider: null,
    usePlayerTheme: true,
    buildSlivers: (context) => (
      stackHeight,
      [
        SliverPersistentHeader(
          delegate: header,
        ),
        ...sessions.map(
          (session) => SliverToBoxAdapter(child: DeviceItem(session)),
        )
      ]
    ),
  );
}

class DeviceItem extends StatefulWidget {
  final SessionInfo session;
  DeviceItem(this.session);

  @override
  State<StatefulWidget> createState() => _DeviceItemState();
}

class _DeviceItemState extends State<DeviceItem> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          setState(() {
            this._loading=true;
          });
        },
        child: Container(
          height: 56,
          padding: const EdgeInsets.all(5),
          child: Row(
            children: [
              const Icon(Icons.laptop),
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Text(
                  "${widget.session.deviceName} - (${widget.session.client})",
                ),
              ),
              const Spacer(flex: 5),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: SizedBox(
                    height: 56,
                    width: 30,
                    child: Center(
                      child: SizedBox(
                        height: 25,
                        width: 25,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
      );
}

class DeviceMenuHeader extends SliverPersistentHeaderDelegate {
  final double _extent = 50;

  @override
  double get maxExtent => _extent;

  @override
  double get minExtent => _extent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        children: [
          // const Icon(Icons.cast),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Text("Play On",
                style: Theme.of(context).textTheme.headlineSmall),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
