import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../shared/repository.dart';

/// Authenticated download rather than a transferable signed URL. No private
/// object bytes, paths or credentials are written to disk by this widget.
class ProfilePhoto extends StatefulWidget {
  final NovaRepository repo;
  final String? path;
  final double height;
  const ProfilePhoto({
    super.key,
    required this.repo,
    this.path,
    this.height = 240,
  });
  @override
  State<ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<ProfilePhoto> {
  Future<Uint8List>? data;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(ProfilePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) load();
  }

  void load() {
    data = widget.path == null ? null : widget.repo.downloadPhoto(widget.path!);
  }

  Widget empty() => Container(
    height: widget.height,
    color: Theme.of(context).colorScheme.secondaryContainer,
    alignment: Alignment.center,
    child: Icon(
      Icons.person_outline,
      size: 64,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    ),
  );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: data == null
        ? empty()
        : FutureBuilder<Uint8List>(
            future: data,
            builder: (context, s) => s.hasData
                ? Image.memory(
                    s.data!,
                    height: widget.height,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    gaplessPlayback: false,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => empty(),
                  )
                : s.hasError
                ? empty()
                : SizedBox(
                    height: widget.height,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
          ),
  );
}
