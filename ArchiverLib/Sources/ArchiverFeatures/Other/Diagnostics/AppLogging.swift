import ArchiverModels
import Logging

/// The one place that decides where the app's logs go.
public enum AppLogging {
    /// Call as the first line of the app's `init()`: a swift-log `Logger` keeps the handler that
    /// was current when it was created, so a logger made earlier never reaches these backends.
    public static func bootstrap() {
        LoggingSystem.bootstrap { label in
            MultiplexLogHandler([OSLogHandler(label: label)])
        }
    }
}
