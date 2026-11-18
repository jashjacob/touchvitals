/// Static app metadata for the About panel — no Info.plist to read from when run via `swift run`
/// rather than as a signed .app bundle, so this is hand-maintained instead of pulled from the
/// bundle.
public enum AppInfo {
    public static let name = "TouchVitals"
    public static let version = "0.1.0 (WIP)"
    public static let credit = "Built by Jash"
    public static let repositoryURL = "https://github.com/jashjacob/touchvitals"
}
