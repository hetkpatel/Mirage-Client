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
import 'package:mirageclient/MiragePhotoData.dart';
import 'package:mirageclient/utils/GalleryPhotoViewWrapper.dart';

class PhotosTab extends StatefulWidget {
  final ValueChanged<int> selected;
  const PhotosTab({super.key, required this.selected});

  @override
  State<PhotosTab> createState() => PhotosTabState();
}

class PhotosTabState extends State<PhotosTab> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _sc = ScrollController();

  List<MiragePhotoData> _photos = [];
  List<PhotoCollection> _photoCollection = [];
  final List<String> _selected = [];
  bool _loading = true, _uploading = false, _processing = false;
  int _complete = 0, _total = 0;
  double _processingProgress = 0.0;
  bool _serverProcessing = false;
  Timer? _timer;

  final ValueNotifier<String> _currentTitleNotifier =
      ValueNotifier<String>("---");

  final double targetRowHeight = 250;
  final double spacing = 4;

  @override
  void initState() {
    super.initState();
    _startPinging();
    getPhotos();
  }

  void getPhotos() async {
    if (context.mounted) {
      setState(() => _loading = true);
    }

    _photos = await MirageClient.getPhotos();
    _photos = _photos.map((file) => file).toList()
      ..sort((a, b) => b.created.compareTo(a.created));

    _photoCollection.clear();
    for (MiragePhotoData m in _photos) {
      bool found = false;
      for (PhotoCollection dc in _photoCollection) {
        if (m.created.month == dc.date.month &&
            m.created.year == dc.date.year) {
          dc.mPhotoData.add(m);
          found = true;
          break;
        }
      }

      if (!found) {
        _photoCollection.add(
            PhotoCollection(date: DateTime(m.created.year, m.created.month))
              ..mPhotoData.add(m));
      }
    }

    _photoCollection = _photoCollection.map((dc) => dc).toList()
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

                        _photos.removeWhere(
                            (element) => _selected.contains(element.id));
                        _photos = _photos.map((file) => file).toList()
                          ..sort((a, b) => b.created.compareTo(a.created));

                        _photoCollection.clear();
                        for (MiragePhotoData m in _photos) {
                          bool found = false;
                          for (PhotoCollection dc in _photoCollection) {
                            if (m.created.month == dc.date.month &&
                                m.created.year == dc.date.year) {
                              dc.mPhotoData.add(m);
                              found = true;
                              break;
                            }
                          }

                          if (!found) {
                            _photoCollection.add(PhotoCollection(
                                date: DateTime(m.created.year, m.created.month))
                              ..mPhotoData.add(m));
                          }
                        }

                        _photoCollection = _photoCollection
                            .map((dc) => dc)
                            .toList()
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

  Widget _buildPhotoTile(PhotoDataWithSize pd) {
    // Move hovering outside the builder
    bool hovering = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => hovering = true),
          onExit: (_) => setState(() => hovering = false),
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                _createRoute(
                  GalleryPhotoViewWrapper(
                    galleryItems: _photos,
                    copyOfSelectedIDs: _selected,
                    initialIndex: _photos.indexOf(pd.mPhotoData),
                    alreadySelected: _selected.contains(pd.mPhotoData.id),
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
                  SizedBox(
                    width: pd.width,
                    height: pd.height,
                    child: BlurHash(
                      hash: pd.mPhotoData.metadata['BlurHash'],
                      image: "${pd.mPhotoData.url}?thumbnail=true",
                      imageFit: BoxFit.cover,
                    ),
                  ),
                  if (hovering || _selected.contains(pd.mPhotoData.id))
                    Positioned(
                      top: 4,
                      left: 4,
                      child: IconButton(
                        onPressed: () {
                          if (_selected.contains(pd.mPhotoData.id)) {
                            _selected.remove(pd.mPhotoData.id);
                          } else {
                            _selected.add(pd.mPhotoData.id);
                          }
                          widget.selected(_selected.length);
                        },
                        icon: Icon(
                          _selected.contains(pd.mPhotoData.id)
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_outlined,
                        ),
                        color: _selected.contains(pd.mPhotoData.id)
                            ? Colors.white
                            : Colors.white54,
                      ),
                    ),
                ],
              ),
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
              : _photos.isEmpty
                  ? Center(
                      child: Text('No photos found'),
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
                        slivers: _photoCollection.map(
                          (collection) {
                            return SliverStickyHeader.builder(
                              builder: (context, state) {
                                String newCurrentTitle =
                                    DateFormat.yMMMM().format(collection.date);
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
                              sliver: SliverLayoutBuilder(
                                builder: (context, constraints) {
                                  final availableWidth =
                                      constraints.crossAxisExtent - spacing * 2;
                                  final rows = _buildRows(collection.mPhotoData,
                                      availableWidth, targetRowHeight);

                                  return SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final row = rows[index];
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            top: index == 0 ? spacing : 0,
                                            bottom: spacing,
                                            left: spacing,
                                            right: spacing,
                                          ),
                                          child: Row(
                                            children:
                                                List.generate(row.length, (i) {
                                              final img = row[i];
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                    right: i < row.length - 1
                                                        ? spacing
                                                        : 0),
                                                // CHILD
                                                child: _buildPhotoTile(img),
                                              );
                                            }),
                                          ),
                                        );
                                      },
                                      childCount: rows.length,
                                    ),
                                  );
                                },
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

  List<List<PhotoDataWithSize>> _buildRows(
    List<MiragePhotoData> images,
    double maxWidth,
    double rowHeight,
  ) {
    List<List<PhotoDataWithSize>> rows = [];
    List<MiragePhotoData> currentRow = [];
    double totalWidth = 0;

    for (var img in images) {
      final scaledWidth = img.aspectRatio * rowHeight;

      // Account for spacing between images
      final spacingWidth = currentRow.isEmpty ? 0 : spacing;

      // If adding this image would exceed the max width, finalize the current row
      if (totalWidth + scaledWidth + spacingWidth > maxWidth &&
          currentRow.isNotEmpty) {
        final scale =
            (maxWidth - (currentRow.length - 1) * spacing) / totalWidth;
        rows.add(
          currentRow.map((image) {
            final w = image.aspectRatio * rowHeight * scale;
            final h = rowHeight * scale;
            return PhotoDataWithSize(mPhotoData: image, width: w, height: h);
          }).toList(),
        );
        currentRow = [];
        totalWidth = 0;
      }

      currentRow.add(img);
      totalWidth += scaledWidth;
    }

    // Handle the last row
    if (currentRow.isNotEmpty) {
      rows.add(
        currentRow.map((image) {
          final w = image.aspectRatio * rowHeight;
          final h = rowHeight;
          return PhotoDataWithSize(mPhotoData: image, width: w, height: h);
        }).toList(),
      );
    }

    return rows;
  }

  Route _createRoute(Widget toPage) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => toPage,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}

class PhotoCollection {
  final DateTime date;
  List<MiragePhotoData> mPhotoData = [];

  PhotoCollection({required this.date});
}

class PhotoDataWithSize {
  final MiragePhotoData mPhotoData;
  final double width;
  final double height;

  PhotoDataWithSize({
    required this.mPhotoData,
    required this.width,
    required this.height,
  });
}
