import 'package:flutter/foundation.dart';
import '../models/constituency.dart';

/// Singleton notifier so any page can observe constituency changes
/// made by any other page, without needing a full state-management solution.
class ConstituencyNotifier {
  ConstituencyNotifier._();
  static final ConstituencyNotifier instance = ConstituencyNotifier._();

  final ValueNotifier<Constituency?> notifier = ValueNotifier<Constituency?>(null);

  Constituency? get current => notifier.value;

  void set(Constituency? c) {
    notifier.value = c;
  }
}
