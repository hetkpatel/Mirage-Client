import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:mirageclient/MirageClient.dart';
import 'package:mirageclient/MiragePhotoData.dart';
import 'package:mirageclient/utils/GalleryPhotoViewWrapper.dart';

class TrashTab extends StatefulWidget {
  final ValueChanged<int> selected;
  const TrashTab({super.key, required this.selected});

  @override
  State<TrashTab> createState() => TrashTabState();
}

class TrashTabState extends State<TrashTab> {
  bool _loading = true;
  List<MiragePhotoData> _trashList = [];
  final List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    getTrash();
  }

  void getTrash() async {
    if (context.mounted) {
      setState(() => _loading = true);
    }

    _trashList = await MirageClient.getTrash();
    _trashList = _trashList.map((file) => file).toList()
      ..sort((a, b) => a.expiry.compareTo(b.expiry));

    if (context.mounted) {
      setState(() => _loading = false);
    }
  }

  void deselectAll() {
    setState(() => _selected.clear());
    widget.selected(_selected.length);
  }

  Future<void> removeTrash() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Restore ${_selected.length} items?'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'No',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (context.mounted) {
                          setState(() => _loading = true);
                        }

                        _trashList.removeWhere(
                            (element) => _selected.contains(element.id));

                        // Remove from trash on server side
                        for (String id in _selected) {
                          await MirageClient.trash(id);
                        }

                        _selected.clear();
                        widget.selected(0);

                        if (context.mounted) {
                          setState(() => _loading = false);
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'Restore',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            physics: const BouncingScrollPhysics(),
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad
            },
            scrollbars: false,
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _trashList.isEmpty
                  ? Center(
                      child: Text('Trash is empty'),
                    )
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: _trashList.length,
                      itemBuilder: (context, index) {
                        final mPhotoItem = _trashList[index];
                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              _createRoute(
                                GalleryPhotoViewWrapper(
                                  galleryItems: _trashList,
                                  copyOfSelectedIDs: _selected,
                                  initialIndex: index,
                                  alreadySelected:
                                      _selected.contains(mPhotoItem.id),
                                  onSelectedCallback: (id) {
                                    if (_selected.contains(id)) {
                                      _selected.remove(id);
                                    } else {
                                      _selected.add(id);
                                    }
                                    widget.selected(_selected.length);
                                  },
                                ),
                              ),
                            );
                            setState(() {
                              widget.selected(_selected.length);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                BlurHash(
                                  hash: mPhotoItem.metadata['BlurHash'],
                                  image: "${mPhotoItem.url}?thumbnail=true",
                                  imageFit: BoxFit.cover,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.center,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.5),
                                        Colors.black.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.center,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.5),
                                        Colors.black.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Text(
                                    "${mPhotoItem.expiry.difference(DateTime.now()).inDays} days left",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (_selected.contains(mPhotoItem.id)) {
                                      _selected.remove(mPhotoItem.id);
                                    } else {
                                      _selected.add(mPhotoItem.id);
                                    }
                                    widget.selected(_selected.length);
                                  },
                                  icon: Icon(
                                    _selected.contains(mPhotoItem.id)
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                  ),
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

Route _createRoute(Widget toPage) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => toPage,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}
