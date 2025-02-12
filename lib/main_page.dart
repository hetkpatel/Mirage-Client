// ignore_for_file: non_constant_identifier_names

import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirageclient/MirageClient.dart';
import 'package:mirageclient/media_tab.dart';
import 'package:mirageclient/trash_tab.dart';
import 'package:mirageclient/utils/AnimatedIndexedStack.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String _appVersion = '';
  Map<String, dynamic> _diskUsage = {
    "filesystem_used_size": 0,
    "filesystem_total_size": 1,
  };
  GlobalKey<MediaTabState> GK_mts = GlobalKey();
  GlobalKey<TrashTabState> GK_trash = GlobalKey();
  final SideMenuController _sideMenuController = SideMenuController();
  int _index = 0;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _getAppVersion();
    _getDiskUsage();
  }

  void _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() => _appVersion = packageInfo.version);
  }

  void _getDiskUsage() async {
    final result = await MirageClient.getDiskUsage();
    setState(() => _diskUsage = result);
  }

  String _getDiskPercentageUsed(used, total) {
    double result = _diskUsage['filesystem_used_size'] /
        _diskUsage['filesystem_total_size'];
    if (result < 0.2) {
      return (result * 100).toStringAsFixed(2);
    } else {
      return (result * 100).toStringAsFixed(0);
    }
  }

  Icon _trashIcon() {
    switch (_index) {
      case 0:
        return Icon(Icons.delete_rounded);
      case 1:
        return Icon(Icons.restore_from_trash_rounded);
      default:
        return Icon(Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selected != 0
          ? AppBar(
              title: Text('$_selected selected'),
              elevation: 10,
              leading: IconButton(
                onPressed: () => GK_mts.currentState!.deselectAll(),
                icon: Icon(Icons.clear_rounded),
              ),
              actions: [
                IconButton(
                  onPressed: () async {
                    switch (_index) {
                      case 0:
                        await GK_mts.currentState!.trash();
                        GK_trash.currentState!.getTrash();
                        break;
                      case 1:
                        await GK_trash.currentState!.removeTrash();
                        GK_mts.currentState!.getMedia();
                        break;
                    }
                  },
                  icon: _trashIcon(),
                )
              ],
            )
          : AppBar(
              title: const Text('Bhojani Drive'),
              leading: null,
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            SizedBox(
              width: 256,
              child: SideMenu(
                controller: _sideMenuController,
                alwaysShowFooter: true,
                style: SideMenuStyle(
                  itemOuterPadding:
                      const EdgeInsets.only(top: 8, left: 8, right: 8),
                  displayMode: SideMenuDisplayMode.open,
                  selectedColor: Theme.of(context).primaryColor,
                  itemBorderRadius: BorderRadius.circular(20),
                  selectedIconColor: Theme.of(context).colorScheme.surface,
                  selectedTitleTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
                items: [
                  SideMenuItem(
                    icon: const Icon(Icons.photo_library_outlined),
                    title: 'Photos',
                    onTap: (index, _) {
                      GK_trash.currentState!.deselectAll();
                      _sideMenuController.changePage(index);
                      setState(() => _index = index);
                    },
                  ),
                  // SideMenuItem(
                  //   icon: const Icon(Icons.search_rounded),
                  //   title: 'Explore',
                  //   onTap: (index, _) {
                  //     _sideMenuController.changePage(index);
                  //     setState(() => _index = index);
                  //   },
                  // ),
                  SideMenuItem(
                    icon: Icon(Icons.delete_rounded),
                    title: 'Trash',
                    onTap: (index, _) {
                      GK_mts.currentState!.deselectAll();
                      _sideMenuController.changePage(index);
                      setState(() => _index = index);
                    },
                  ),
                  // const SideMenuItem(
                  //   icon: Icon(Icons.map_rounded),
                  //   // onTap: (index, _) => _sideMenuController.changePage(index),
                  //   title: 'Map',
                  // ),
                  // const SideMenuItem(
                  //   icon: Icon(Icons.photo_album_rounded),
                  //   // onTap: (index, _) => _sideMenuController.changePage(index),
                  //   title: 'Albums',
                  // ),
                ],
                footer: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Storage',
                              style: GoogleFonts.overpass(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${filesize(_diskUsage['filesystem_used_size'])} of ${filesize(_diskUsage['filesystem_total_size'])} used (${_getDiskPercentageUsed(_diskUsage['filesystem_used_size'], _diskUsage['filesystem_total_size'])}%)",
                            ),
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeInOutQuart,
                              tween: Tween<double>(
                                begin: 0,
                                end: _diskUsage['filesystem_used_size'] /
                                    _diskUsage['filesystem_total_size'],
                              ),
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                value: value,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      _appVersion,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: AnimatedIndexedStack(
                index: _index,
                children: [
                  MediaTab(
                    key: GK_mts,
                    selected: (value) => setState(() => _selected = value),
                  ),
                  TrashTab(
                    key: GK_trash,
                    selected: (value) => setState(() => _selected = value),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
