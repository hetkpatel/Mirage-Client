import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flexible_scrollbar/flexible_scrollbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_session_manager/flutter_session_manager.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mirageclient/MirageClient.dart';
import 'package:mirageclient/MirageFile.dart';
import 'package:mirageclient/utils/GalleryPhotoViewWrapper.dart';

class MediaTab extends StatefulWidget {
  final ValueChanged<int> selected;
  const MediaTab({super.key, required this.selected});

  @override
  State<MediaTab> createState() => MediaTabState();
}

class MediaTabState extends State<MediaTab> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _sc = ScrollController();

  List<MirageFile> _media = [];
  List<DateCollection> _dcs = [];
  final List<String> _selected = [];
  bool _loading = true, _uploading = false, _processing = false;
  int _complete = 0, _total = 0;
  double _processingProgress = 0.0;
  bool _serverProcessing = false;
  Timer? _timer;

  final ValueNotifier<String> _currentTitleNotifier =
      ValueNotifier<String>("---");

  @override
  void initState() {
    super.initState();
    _startPinging();
    getMedia();
  }

  void getMedia() async {
    if (context.mounted) {
      setState(() => _loading = true);
    }

    _media = await MirageClient.getMedia();
    _media = _media.map((file) => file).toList()
      ..sort((a, b) => b.created.compareTo(a.created));

    _dcs.clear();
    for (MirageFile m in _media) {
      bool found = false;
      for (DateCollection dc in _dcs) {
        if (m.created.month == dc.date.month &&
            m.created.year == dc.date.year) {
          dc.mirageFiles.add(m);
          found = true;
          break;
        }
      }

      if (!found) {
        _dcs.add(DateCollection(date: DateTime(m.created.year, m.created.month))
          ..mirageFiles.add(m));
      }
    }

    _dcs = _dcs.map((dc) => dc).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (context.mounted) {
      setState(() => _loading = false);
    }
  }

  void _uploadItems(List<XFile> items) async {
    Future<List<T>> progressWait<T>(List<Future<T>> futures,
        void Function(int completed, int total) progress) {
      int total = futures.length;
      int completed = 0;
      void complete() {
        completed++;
        progress(completed, total);
      }

      return Future.wait<T>(
          [for (var future in futures) future.whenComplete(complete)]);
    }

    await progressWait(
      items
          .map(
            (e) => MirageClient.uploadFile(e),
          )
          .toList(),
      (complete, total) {
        if (context.mounted) {
          setState(() {
            _complete = complete;
            _total = total;
            _uploading = complete != total;
          });
        }
      },
    );

    await MirageClient.startProcessing(pullUploads: true);
    _startPinging();
  }

  void _startPinging() {
    checkStatus(_) async {
      try {
        String statusUrl = '${await SessionManager().get("server")}/status';
        final response = await http.get(Uri.parse(statusUrl), headers: {
          HttpHeaders.authorizationHeader: await SessionManager().get("auth"),
        });

        if (response.statusCode == 200) {
          _stopPinging();
        } else if (response.statusCode == 425) {
          Map<String, dynamic> result =
              (jsonDecode(response.body) as Map<String, dynamic>);
          if (context.mounted) {
            setState(() {
              _processing = true;
              _processingProgress = result['progress'];
              _serverProcessing = result['processing_similar'];
            });
          }
        } else {
          if (kDebugMode) {
            print('Ping failed: ${response.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error occurred while pinging: $e');
        }
      }
    }

    checkStatus(null);
    _timer = Timer.periodic(const Duration(seconds: 15), checkStatus);
  }

  void _stopPinging() {
    _timer?.cancel();
    if (context.mounted) {
      setState(() {
        _processing = false;
        _serverProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sc.dispose();
    super.dispose();
  }

  Widget _uploadStatus() {
    if (_uploading) {
      return SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(
          value: _complete / _total,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          strokeCap: StrokeCap.round,
        ),
      );
    } else if (_processing) {
      return SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(
          value: !_serverProcessing ? _processingProgress : null,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          strokeCap: StrokeCap.round,
        ),
      );
    } else {
      return const Icon(Icons.add_photo_alternate_outlined);
    }
  }

  void deselectAll() {
    setState(() => _selected.clear());
    widget.selected(_selected.length);
  }

  Future<void> trash() async {
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
                Text(
                    'Are you sure you want to delete ${_selected.length} items?'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        return;
                      },
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

                        _media.removeWhere(
                            (element) => _selected.contains(element.id));
                        _media = _media.map((file) => file).toList()
                          ..sort((a, b) => b.created.compareTo(a.created));

                        _dcs.clear();
                        for (MirageFile m in _media) {
                          bool found = false;
                          for (DateCollection dc in _dcs) {
                            if (m.created.month == dc.date.month &&
                                m.created.year == dc.date.year) {
                              dc.mirageFiles.add(m);
                              found = true;
                              break;
                            }
                          }

                          if (!found) {
                            _dcs.add(DateCollection(
                                date: DateTime(m.created.year, m.created.month))
                              ..mirageFiles.add(m));
                          }
                        }

                        _dcs = _dcs.map((dc) => dc).toList()
                          ..sort((a, b) => b.date.compareTo(a.date));

                        // Trash on server side
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
                        'Trash',
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
              : _media.isEmpty
                  ? Center(
                      child: Text('No media found'),
                    )
                  : FlexibleScrollbar(
                      controller: _sc,
                      jumpOnScrollLineTapped: false,
                      scrollThumbBuilder: (p0) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          width: 10,
                          height: p0.thumbMainAxisSize,
                        );
                      },
                      scrollLabelBuilder: (p0) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: ValueListenableBuilder(
                              valueListenable: _currentTitleNotifier,
                              builder: (context, value, child) => Text(value),
                            ),
                          ),
                        );
                      },
                      child: CustomScrollView(
                        controller: _sc,
                        slivers: _dcs.map(
                          (dc) {
                            return SliverStickyHeader.builder(
                              builder: (context, state) {
                                String newCurrentTitle =
                                    DateFormat.yMMMM().format(dc.date);
                                if (state.isPinned &&
                                    _currentTitleNotifier.value.toString() !=
                                        newCurrentTitle) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _currentTitleNotifier.value =
                                        newCurrentTitle;
                                  });
                                }

                                return Container(
                                  height: 60,
                                  color: Theme.of(context).colorScheme.surface,
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 16.0),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    newCurrentTitle,
                                    style: TextStyle(fontSize: 24),
                                  ),
                                );
                              },
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  childCount: dc.mirageFiles.length,
                                  (context, index) {
                                    final mediaItem = dc.mirageFiles[index];
                                    return GestureDetector(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          _createRoute(
                                            GalleryPhotoViewWrapper(
                                              galleryItems: _media,
                                              copyOfSelectedIDs: _selected,
                                              initialIndex:
                                                  _media.indexOf(mediaItem),
                                              alreadySelected: _selected
                                                  .contains(mediaItem.id),
                                              onSelectedCallback: (id) {
                                                if (_selected.contains(id)) {
                                                  _selected.remove(id);
                                                } else {
                                                  _selected.add(id);
                                                }
                                                widget
                                                    .selected(_selected.length);
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
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          children: [
                                            BlurHash(
                                              hash: mediaItem
                                                  .metadata['BlurHash'],
                                              image:
                                                  "${mediaItem.url}?thumbnail=true",
                                              imageFit: BoxFit.cover,
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.center,
                                                  colors: [
                                                    Colors.black
                                                        .withValues(alpha: 0.5),
                                                    Colors.black
                                                        .withValues(alpha: 0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                if (_selected
                                                    .contains(mediaItem.id)) {
                                                  _selected
                                                      .remove(mediaItem.id);
                                                } else {
                                                  _selected.add(mediaItem.id);
                                                }
                                                widget
                                                    .selected(_selected.length);
                                              },
                                              icon: Icon(
                                                _selected.contains(mediaItem.id)
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
                            );
                          },
                        ).toList(),
                      ),
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _uploading || _processing
            ? Theme.of(context).colorScheme.surfaceContainerLowest
            : null,
        tooltip: _uploading
            ? "Uploading: ${((_complete / _total) * 100).round()}%"
            : _processing
                ? _serverProcessing
                    ? "Finalizing uploads"
                    : "Processing: ${(_processingProgress * 100).round()}%"
                : null,
        onPressed: _loading || _uploading || _processing
            ? null
            : () async {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return Dialog(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: FutureBuilder<List<XFile>>(
                          future: _picker.pickMultipleMedia(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CupertinoActivityIndicator();
                            } else if (snapshot.hasError) {
                              debugPrintStack(stackTrace: snapshot.stackTrace);
                              return Center(
                                child: Text(
                                  'Error: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            } else {
                              if (snapshot.data!.isEmpty) {
                                Navigator.pop(context);
                                return const SizedBox.shrink();
                              }
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      'Ready to upload ${snapshot.data!.length} items'),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          if (context.mounted) {
                                            setState(() {
                                              _complete = 0;
                                              _total = snapshot.data!.length;
                                              _uploading = _complete != _total;
                                            });
                                          }
                                          _uploadItems(snapshot.data!);
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: Text(
                                          'Upload',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
        heroTag: 'upload_fab',
        child: _uploadStatus(),
      ),
    );
  }
}

class DateCollection {
  final DateTime date;
  List<MirageFile> mirageFiles = [];

  DateCollection({required this.date});
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
