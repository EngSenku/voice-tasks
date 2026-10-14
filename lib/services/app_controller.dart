import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'store.dart';

/// Routes taps from notifications and the "Record" shortcut to the UI.
class AppController extends ChangeNotifier {
  static final AppController i = AppController._();
  AppController._();

  String? pending;

  void post(String action) {
    pending = action;
    notifyListeners();
  }

  String? take() {
    final p = pending;
    pending = null;
    return p;
  }

  void openFromPayload(String p) {
    if (p == 'briefing') {
      post('briefing');
    } else if (p == 'checkin') {
      post('checkin');
    } else if (p.startsWith('task:')) {
      post('calendar');
    }
  }

  void onNotification(NotificationResponse r) {
    final p = r.payload ?? '';
    final a = r.actionId;
    if (p.startsWith('task:') && a != null && a.isNotEmpty) {
      final t = TaskStore.i.byId(p.substring(5));
      if (t == null) return;
      if (a == 'done') {
        TaskStore.i.complete(t);
      } else if (a == 'push') {
        TaskStore.i.push(t);
      } else if (a == 'drop') {
        TaskStore.i.drop(t);
      }
      return;
    }
    openFromPayload(p);
  }
}
