import SwiftUI
import WidgetKit

/// Extension `IronlyWidgets` (05 Bản 3 TD3-02): widget S-70, thẻ màn hình khóa
/// S-71.
@main
struct IronlyWidgetsBundle: WidgetBundle {
  var body: some Widget {
    IronlyWidget()
    IronlySessionActivity()
  }
}
