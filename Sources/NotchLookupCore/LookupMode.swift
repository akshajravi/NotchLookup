import Foundation

public enum LookupMode: String, CaseIterable, Sendable {
    case explain = "Explain"
    case define  = "Define"
    case math    = "Math"
}
