import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/photo_processing.dart';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import 'profile_photo.dart';

class PhotoEditor extends StatefulWidget {
  final NovaRepository repo;
  const PhotoEditor({super.key, required this.repo});
  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  late Future<List<DbRow>> data = widget.repo.photos();
  double? progress;
  bool busy = false;
  void reload() => setState(() {
    data = widget.repo.photos();
  });
  Future<void> upload() async {
    if (busy) return;
    final s = Strings.of(context);
    setState(() => busy = true);
    await guarded(context, () async {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      if (await picked.length() > 5242880) {
        throw StateError('Image exceeds 5MB');
      }
      final raw = await picked.readAsBytes();
      final bytes = await compute(processProfilePhoto, raw);
      if (!mounted) return;
      var visibility = 'public';
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(s.t('معاينة قبل الرفع', 'Preview before upload')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.memory(bytes, height: 220),
                  DropdownButton<String>(
                    value: visibility,
                    isExpanded: true,
                    items: [
                      for (final v in ['public', 'matches', 'private'])
                        DropdownMenuItem(
                          value: v,
                          child: Text(
                            s.t(
                              {
                                'public': 'للملف المسموح له بالظهور',
                                'matches': 'للتطابقات فقط',
                                'private': 'خاصة بي فقط',
                              }[v]!,
                              {
                                'public': 'Visible profile',
                                'matches': 'Matches only',
                                'private': 'Only me',
                              }[v]!,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() => visibility = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.t('إلغاء', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.t('رفع وحفظ', 'Upload and save')),
              ),
            ],
          ),
        ),
      );
      if (accepted != true) return;
      final photo = Map<String, dynamic>.from(
        await widget.repo.client.rpc(
          'prepare_profile_photo',
          params: {'photo_visibility': visibility},
        ),
      );
      try {
        setState(() => progress = 0);
        await widget.repo.client.storage
            .from('private-media')
            .uploadBinary(
              photo['path'],
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
              retryAttempts: 1,
            );
        if (mounted) setState(() => progress = .85);
        await widget.repo.client.rpc(
          'finalize_profile_photo',
          params: {'photo_id': photo['id']},
        );
        if (mounted) setState(() => progress = 1);
      } catch (_) {
        try {
          await widget.repo.removePhoto(photo);
        } catch (_) {
          /* User can retry deletion of pending upload. */
        }
        rethrow;
      }
      if (mounted) reload();
    });
    if (mounted) {
      setState(() {
        busy = false;
        progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.t('صورك • حتى 6 صور', 'Your photos • up to 6'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          s.t(
            'JPEG أو PNG أو WebP، حتى 5 ميغابايت. تُزال بيانات الموقع من الصور. الصورة الخاصة لا تظهر للآخرين.',
            'JPEG, PNG or WebP, up to 5MB. Location metadata is stripped. Private photos are never shown to others.',
          ),
        ),
        if (progress != null)
          LinearProgressIndicator(value: progress == 1 ? 1 : null),
        AsyncPane<List<DbRow>>(
          future: data,
          retry: reload,
          builder: (photos) => Column(
            children: [
              if (photos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    s.t(
                      'أضف صورة عندما تكون مستعدًا.',
                      'Add a photo whenever you are ready.',
                    ),
                  ),
                ),
              for (var i = 0; i < photos.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ProfilePhoto(
                          repo: widget.repo,
                          path: photos[i]['ready'] == true
                              ? photos[i]['path']
                              : null,
                          height: 140,
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            IconButton(
                              tooltip: s.t('تقديم الصورة', 'Move earlier'),
                              onPressed: busy || i == 0
                                  ? null
                                  : () => guarded(context, () async {
                                      final ids = photos
                                          .map((p) => p['id'] as String)
                                          .toList();
                                      final v = ids.removeAt(i);
                                      ids.insert(i - 1, v);
                                      await widget.repo.photoOrder(ids);
                                      reload();
                                    }),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            PopupMenuButton<String>(
                              tooltip: s.t('خصوصية الصورة', 'Photo privacy'),
                              initialValue: photos[i]['visibility'],
                              onSelected: (v) => guarded(context, () async {
                                await widget.repo.photoPrivacy(
                                  photos[i]['id'],
                                  v,
                                );
                                reload();
                              }),
                              itemBuilder: (_) => [
                                for (final v in [
                                  'public',
                                  'matches',
                                  'private',
                                ])
                                  CheckedPopupMenuItem(
                                    value: v,
                                    checked: photos[i]['visibility'] == v,
                                    child: Text(
                                      s.t(
                                        {
                                          'public': 'للملف',
                                          'matches': 'للتطابقات',
                                          'private': 'خاصة',
                                        }[v]!,
                                        {
                                          'public': 'Profile',
                                          'matches': 'Matches',
                                          'private': 'Private',
                                        }[v]!,
                                      ),
                                    ),
                                  ),
                              ],
                              icon: Icon(
                                photos[i]['visibility'] == 'public'
                                    ? Icons.public
                                    : Icons.lock_outline,
                              ),
                            ),
                            IconButton(
                              tooltip: s.t('حذف الصورة', 'Delete photo'),
                              onPressed: busy
                                  ? null
                                  : () => guarded(context, () async {
                                      await widget.repo.removePhoto(photos[i]);
                                      reload();
                                    }),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        if (photos[i]['ready'] != true)
                          Text(
                            s.t(
                              'رفع غير مكتمل؛ احذف الصورة وأعد المحاولة.',
                              'Upload incomplete; delete and retry.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: busy || photos.length >= 6 ? null : upload,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  busy
                      ? s.t('جارٍ الرفع…', 'Uploading…')
                      : s.t('اختيار صورة', 'Choose photo'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
