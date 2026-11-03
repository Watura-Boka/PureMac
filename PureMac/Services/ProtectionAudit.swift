import Darwin
import Foundation

enum ProtectionCheck: String, CaseIterable, Identifiable, Sendable {
    case gatekeeper
    case fileVault
    case firewall
    case systemIntegrityProtection
    case xProtect

    var id: String { rawValue }
}

enum ProtectionStatus: Sendable, Equatable {
    case enabled
    case disabled
    case unknown
}

struct ProtectionFinding: Identifiable, Sendable, Equatable {
    let check: ProtectionCheck
    let status: ProtectionStatus
    let detail: String
    let version: String?

    var id: ProtectionCheck { check }
}

struct ProtectionSnapshot: Sendable, Equatable {
    let findings: [ProtectionFinding]
    let checkedAt: Date
}

enum ProtectionCommand: CaseIterable, Hashable, Sendable {
    case gatekeeper
    case fileVault
    case firewall
    case systemIntegrityProtection

    var executableURL: URL {
        switch self {
        case .gatekeeper:
            return URL(fileURLWithPath: "/usr/sbin/spctl")
        case .fileVault:
            return URL(fileURLWithPath: "/usr/bin/fdesetup")
        case .firewall:
            return URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw")
        case .systemIntegrityProtection:
            return URL(fileURLWithPath: "/usr/bin/csrutil")
        }
    }

    var arguments: [String] {
        switch self {
        case .gatekeeper:
            return ["--status"]
        case .fileVault:
            return ["status"]
        case .firewall:
            return ["--getglobalstate"]
        case .systemIntegrityProtection:
            return ["status"]
        }
    }

    var check: ProtectionCheck {
        switch self {
        case .gatekeeper:
            return .gatekeeper
        case .fileVault:
            return .fileVault
        case .firewall:
            return .firewall
        case .systemIntegrityProtection:
            return .systemIntegrityProtection
        }
    }
}

struct ProtectionCommandResult: Sendable, Equatable {
    let exitCode: Int32?
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let cancelled: Bool
    let launchError: String?

    var succeeded: Bool {
        exitCode == 0 && !timedOut && !cancelled && launchError == nil
    }
}

struct ProtectionProcessRequest: Sendable {
    let executableURL: URL
    let arguments: [String]
}
