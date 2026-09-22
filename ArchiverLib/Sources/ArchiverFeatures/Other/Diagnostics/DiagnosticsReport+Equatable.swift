import Diagnostics

/// `Settings.State` needs `Equatable` to hold the generated report until the user confirms sending it.
extension DiagnosticsReport: @retroactive Equatable {
    public static func == (lhs: DiagnosticsReport, rhs: DiagnosticsReport) -> Bool {
        lhs.filename == rhs.filename && lhs.mimeType.rawValue == rhs.mimeType.rawValue && lhs.data == rhs.data
    }
}
