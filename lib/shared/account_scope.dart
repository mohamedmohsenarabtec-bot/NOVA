import 'package:flutter/widgets.dart';

import 'repository.dart';

class AccountScope extends InheritedWidget {
  final NovaRepository repo;
  const AccountScope({super.key, required this.repo, required super.child});
  static NovaRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.repo;
  @override
  bool updateShouldNotify(AccountScope oldWidget) => oldWidget.repo != repo;
}
