import Foundation
import SwiftUI

/// Provider-agnostic representation of a code review (MR in GitLab, PR in GitHub)
struct CodeReview: Identifiable, Equatable {
    let id: Int
    /// Provider-specific number (iid in GitLab, number in GitHub)
    let number: Int
    let title: String
    let state: CodeReviewState
    let webUrl: String
    let pipeline: CIPipeline?
}

/// State of a code review
enum CodeReviewState: Equatable {
    case open
    case merged
    case closed
}

/// Provider-agnostic representation of a CI pipeline or check run
struct CIPipeline: Identifiable, Equatable {
    let id: Int
    let status: CIPipelineStatus
    let webUrl: String?
}

/// Normalized CI pipeline statuses across providers
enum CIPipelineStatus: Equatable {
    case success
    case running
    case pending
    case failed
    case canceled
    case skipped
    case manual
    case created
    case waiting
    case preparing
    case unknown(String)

    var displayName: String {
        switch self {
        case .success: return "Passed"
        case .running: return "Running"
        case .pending: return "Pending"
        case .failed: return "Failed"
        case .canceled: return "Canceled"
        case .skipped: return "Skipped"
        case .manual: return "Manual"
        case .created: return "Created"
        case .waiting: return "Waiting"
        case .preparing: return "Preparing"
        case .unknown(let raw): return raw.capitalized
        }
    }

    var systemImageName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .running: return "play.circle.fill"
        case .pending, .waiting, .preparing: return "clock.fill"
        case .failed: return "xmark.circle.fill"
        case .canceled: return "stop.circle.fill"
        case .skipped: return "forward.circle.fill"
        case .manual: return "hand.raised.circle.fill"
        case .created: return "circle.dashed"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .running: return .blue
        case .pending, .waiting, .preparing, .manual: return .orange
        case .failed: return .red
        case .canceled, .skipped, .created: return .secondary
        case .unknown: return .secondary
        }
    }

    var isRunning: Bool {
        self == .running || self == .pending
    }
}
