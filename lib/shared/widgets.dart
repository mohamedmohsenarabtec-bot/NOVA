import 'package:flutter/material.dart';

import '../core/strings.dart';

class AsyncPane<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T) builder;
  final VoidCallback retry;
  const AsyncPane({
    super.key,
    required this.future,
    required this.builder,
    required this.retry,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(Strings.of(context).error),
              ),
              FilledButton(
                onPressed: retry,
                child: Text(Strings.of(context).retry),
              ),
            ],
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return builder(snapshot.data as T);
    },
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Future<void> guarded(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(Strings.of(context).error)));
    }
  }
}
