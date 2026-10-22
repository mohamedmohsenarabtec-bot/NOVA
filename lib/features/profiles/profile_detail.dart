import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import 'profile_photo.dart';
import 'profile_fields.dart';

Future<void> showProfileDetail(
  BuildContext context,
  DbRow profile, {
  NovaRepository? repo,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      maxChildSize: .95,
      minChildSize: .4,
      builder: (c, scroll) => repo == null
          ? PublicProfileBody(profile: profile, scroll: scroll)
          : AsyncPane<DbRow>(
              future: repo.publicProfile(profile['id']),
              retry: () => Navigator.pop(c),
              builder: (p) =>
                  PublicProfileBody(profile: p, repo: repo, scroll: scroll),
            ),
    ),
  );
}

class PublicProfileBody extends StatelessWidget {
  final DbRow profile;
  final NovaRepository? repo;
  final ScrollController? scroll;
  const PublicProfileBody({
    super.key,
    required this.profile,
    this.repo,
    this.scroll,
  });
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final photos = profile['photos'] as List? ?? [];
    final details = profile['details'] as Map? ?? {};
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${profile['display_name']}، ${profile['age']}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if ((profile['username'] ?? '') != '') Text('@${profile['username']}'),
        if (repo != null) ...[
          const SizedBox(height: 20),
          if (photos.isEmpty)
            ProfilePhoto(repo: repo!)
          else
            for (final photo in photos)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProfilePhoto(repo: repo!, path: photo['path']),
              ),
        ],
        if ((profile['city'] ?? '') != '')
          ListTile(
            leading: const Icon(Icons.location_city),
            title: Text(profile['city']),
          ),
        if ((profile['bio'] ?? '') != '')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(profile['bio']),
          ),
        if (profile['verified'] == true)
          Chip(
            avatar: const Icon(Icons.verified_outlined),
            label: Text(s.t('توثيق تمت مراجعته', 'Verification reviewed')),
          ),
        if (profile['intention'] != null)
          Text(
            s.t(
              {
                    'marriage': 'زواج',
                    'serious': 'علاقة جادة',
                    'dating': 'تعارف',
                    'friendship': 'صداقة',
                    'social': 'تواصل اجتماعي',
                  }[profile['intention']] ??
                  '',
              {
                    'marriage': 'Marriage',
                    'serious': 'Serious relationship',
                    'dating': 'Dating',
                    'friendship': 'Friendship',
                    'social': 'Social connection',
                  }[profile['intention']] ??
                  '',
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in profile['interests'] as List? ?? [])
              Chip(label: Text(label.toString())),
          ],
        ),
        if ((profile['languages'] as List? ?? []).isNotEmpty)
          Text(
            s.t(
              'اللغات: ${(profile['languages'] as List).join(', ')}',
              'Languages: ${(profile['languages'] as List).join(', ')}',
            ),
          ),
        for (final key in ProfileFields.details.keys)
          if (details[key] != null)
            ListTile(
              title: Text(
                s.t(
                  ProfileFields.details[key]![0],
                  ProfileFields.details[key]![1],
                ),
              ),
              subtitle: Text(details[key]),
            ),
        const SizedBox(height: 20),
        Text(
          s.t(
            'تظهر فقط التفاصيل التي سمح صاحب الملف بعرضها. الدردشة بعد إعجاب متبادل.',
            'Only details shared by the profile owner are displayed. Chat opens after a mutual like.',
          ),
        ),
      ],
    );
  }
}
