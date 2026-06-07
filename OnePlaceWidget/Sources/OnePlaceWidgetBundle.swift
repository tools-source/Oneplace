import SwiftUI
import WidgetKit

@main
struct OnePlaceWidgetBundle: WidgetBundle {
    var body: some Widget {
        OnePlaceTasksWidget()
        OnePlaceLiveActivity()
    }
}
