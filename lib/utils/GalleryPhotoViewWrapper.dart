// ignore_for_file: file_names

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:file_saver/file_saver.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_session_manager/flutter_session_manager.dart';
import 'package:intl/intl.dart';
import 'package:mirageclient/MiragePhotoData.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';

class GalleryPhotoViewWrapper extends StatefulWidget {
  final int initialIndex;
  final bool alreadySelected;
  final PageController pageController;
  final List<MiragePhotoData> galleryItems;
  final List<String> copyOfSelectedIDs;
  final Function(String) onSelectedCallback;

  GalleryPhotoViewWrapper({
    super.key,
    this.initialIndex = 0,
    required this.alreadySelected,
    required this.galleryItems,
    required this.copyOfSelectedIDs,
    required this.onSelectedCallback,
  }) : pageController = PageController(initialPage: initialIndex);

  @override
  State<StatefulWidget> createState() {
    return _GalleryPhotoViewWrapperState();
  }
}

class _GalleryPhotoViewWrapperState extends State<GalleryPhotoViewWrapper> {
  late int _currentIndex = widget.initialIndex;
  late List<String> copyOfSelectedIDs = widget.copyOfSelectedIDs;

  void onPageChanged(int index) {
    if (context.mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.galleryItems[_currentIndex].name),
        actions: [
          IconButton(
            onPressed: () {
              if (copyOfSelectedIDs
                  .contains(widget.galleryItems[_currentIndex].id)) {
                copyOfSelectedIDs.remove(widget.galleryItems[_currentIndex].id);
              } else {
                copyOfSelectedIDs.add(widget.galleryItems[_currentIndex].id);
              }
              setState(() {});
            },
            icon: Icon(
              copyOfSelectedIDs.contains(widget.galleryItems[_currentIndex].id)
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
            ),
          ),
          IconButton(
            onPressed: () async {
              FileSaver.instance.saveFile(
                name: widget.galleryItems[_currentIndex].name,
                link: LinkDetails(
                  link: widget.galleryItems[_currentIndex].url,
                  headers: {
                    HttpHeaders.authorizationHeader:
                        await SessionManager().get("auth"),
                  },
                  queryParameters: {"downloadable": "true"},
                ),
              );
            },
            icon: Icon(Icons.download_rounded),
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.galleryItems[_currentIndex].name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Name',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.yMMMMd().add_jm().format(
                                  widget.galleryItems[_currentIndex].created),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Date',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.galleryItems[_currentIndex]
                                      .metadata['Width']
                                      .toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Width',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            SizedBox(width: 16),
                            Text(
                              '×',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.galleryItems[_currentIndex]
                                      .metadata['Height']
                                      .toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Height',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              filesize(widget.galleryItems[_currentIndex]
                                  .metadata["FileSize"]),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Size',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            icon: Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(color: Colors.black),
        constraints: BoxConstraints.expand(
          height: MediaQuery.of(context).size.height,
        ),
        child: Row(
          children: [
            FloatingActionButton(
              child: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() {
                if (_currentIndex != 0) {
                  widget.pageController.previousPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutQuart,
                  );
                }
              }),
            ),
            Expanded(
              child: PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: _buildItem,
                itemCount: widget.galleryItems.length,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: widget.pageController,
                onPageChanged: onPageChanged,
                gaplessPlayback: true,
              ),
            ),
            FloatingActionButton(
              child: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() {
                if (_currentIndex != widget.galleryItems.length) {
                  widget.pageController.nextPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutQuart,
                  );
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    final MiragePhotoData item = widget.galleryItems[index];
    return item.type == MirageType.video
        ? PhotoViewGalleryPageOptions.customChild(
            child: Center(
              child: MirageVideo(
                url: item.url,
              ),
            ),
            initialScale: PhotoViewComputedScale.contained,
          )
        : PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(
              item.url,
              imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
              // headers: MirageClient.headers,
            ),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
          );
  }
}

class MirageVideo extends StatefulWidget {
  final String url;
  const MirageVideo({super.key, required this.url});

  @override
  State<MirageVideo> createState() => _MirageVideoState();
}

class _MirageVideoState extends State<MirageVideo> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      // httpHeaders: MirageClient.headers,
      videoPlayerOptions: VideoPlayerOptions(
        webOptions: const VideoPlayerWebOptions(
          allowContextMenu: false,
          controls: VideoPlayerWebOptionsControls.enabled(
            allowFullscreen: true,
            allowDownload: true,
          ),
        ),
      ),
    )..initialize().then((_) {
        setState(() {
          controller.play();
        });
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: controller.value.isInitialized
          ? AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
