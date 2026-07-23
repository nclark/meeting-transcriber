import Foundation

// Moved out of AppSettings.swift to bring that file under the
// file_length cap (line-cap split); no code changes.
enum ProtocolProvider: String, CaseIterable {
    #if !APPSTORE
        case claudeCLI
    #endif
    case openAICompatible
    case none // swiftlint:disable:this discouraged_none_name

    var label: String {
        switch self {
        #if !APPSTORE
            case .claudeCLI: "Claude CLI"
        #endif

        case .openAICompatible: "OpenAI-Compatible API"

        case .none: "None (Transcript Only)"
        }
    }
}
