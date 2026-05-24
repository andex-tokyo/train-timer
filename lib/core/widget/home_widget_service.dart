import 'package:home_widget/home_widget.dart';

import 'widget_payload.dart';

class HomeWidgetService {
  static const widgetReceiverName = 'TrainTimerWidgetReceiver';

  Future<void> update(WidgetPayload payload) async {
    for (final entry in payload.toMap().entries) {
      final value = entry.value;
      if (value is bool) {
        await HomeWidget.saveWidgetData<bool>(entry.key, value);
      } else if (value is int) {
        await HomeWidget.saveWidgetData<int>(entry.key, value);
      } else {
        await HomeWidget.saveWidgetData<String>(entry.key, value.toString());
      }
    }
    await HomeWidget.updateWidget(androidName: widgetReceiverName);
  }
}
