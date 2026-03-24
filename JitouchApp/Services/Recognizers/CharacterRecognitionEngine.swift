import CoreGraphics
import Foundation

struct CharacterStrokeGeometry {
    let start: CGPoint
    let end: CGPoint
    let top: CGFloat
    let bottom: CGFloat
    let left: CGFloat
    let right: CGFloat

    var verticalSpan: CGFloat {
        max(top - bottom, 0.000_000_01)
    }

    var horizontalSpan: CGFloat {
        max(right - left, 0.000_000_01)
    }

    var normalizedVerticalDelta: CGFloat {
        (end.y - start.y) / verticalSpan
    }

    var normalizedInverseVerticalDelta: CGFloat {
        (start.y - end.y) / verticalSpan
    }
}

struct CharacterRecognitionEngine {
    private static let gaussianSigma = 0.3
    private static let gaussianMax = gaussianValue(at: 0)
    private static let gaussianMin = gaussianValue(at: 1)
    private static let templates: [CharacterTemplate] = [
        .init(value: "A", segments: [.degrees(65, span: 20), .degrees(-65, span: 20)]),
        .init(value: "B", segments: [.degrees(90, span: 30), .degrees(-45, span: 50), .degrees(-135, span: 30), .degrees(-45, span: 30), .degrees(-135, span: 30)]),
        .init(value: "C", segments: [.degrees(-135, span: 30), .degrees(-45, span: 30), .degrees(0, span: 30)]),
        .init(value: "D", segments: [.degrees(90, span: 30), .degrees(-45, span: 20), .degrees(-135, span: 20)]),
        .init(value: "E", segments: [.degrees(-135, span: 30), .degrees(-45, span: 30), .degrees(-135, span: 30), .degrees(-45, span: 30)]),
        .init(value: "F", segments: [.degrees(-180, span: 20), .degrees(-90, span: 20)]),
        .init(value: "G", segments: [.degrees(-135, span: 30), .degrees(-45, span: 30), .degrees(45, span: 30), .degrees(180, span: 30)]),
        .init(value: "H", segments: [.degrees(-90, span: 20), .degrees(90, span: 30), .degrees(0, span: 60), .degrees(-90, span: 30)]),
        .init(value: "Down", segments: [.degrees(-90, span: 20)]),
        .init(value: "Up", segments: [.degrees(90, span: 20)]),
        .init(value: "Y", segments: [.degrees(-60, span: 30), .degrees(60, span: 20), .degrees(-120, span: 30)]),
        .init(value: "J", segments: [.degrees(-90, span: 20), .degrees(170, span: 30)]),
        .init(value: "K", segments: [.degrees(-135, span: 30), .degrees(90, span: 30), .degrees(-45, span: 30)]),
        .init(value: "L", segments: [.degrees(-90, span: 20), .degrees(0, span: 20)]),
        .init(value: "M", segments: [.degrees(60, span: 30), .degrees(-60, span: 30), .degrees(60, span: 30), .degrees(-60, span: 30)]),
        .init(value: "N", segments: [.degrees(90, span: 20), .degrees(-60, span: 30), .degrees(90, span: 20)]),
        .init(value: "O", segments: [.degrees(-135, span: 30), .degrees(-60, span: 30), .degrees(60, span: 30), .degrees(135, span: 30)]),
        .init(value: "P", segments: [.degrees(90, span: 30), .degrees(-45, span: 20), .degrees(-135, span: 20)]),
        .init(value: "Q", segments: [.degrees(-135, span: 30), .degrees(-60, span: 30), .degrees(60, span: 30), .degrees(110, span: 30), .degrees(-60, span: 20)]),
        .init(value: "R", segments: [.degrees(90, span: 20), .degrees(-45, span: 30), .degrees(-135, span: 30), .degrees(-45, span: 30)]),
        .init(value: "S", segments: [.degrees(-135, span: 30), .degrees(-45, span: 30), .degrees(-135, span: 30), .degrees(180, span: 50)]),
        .init(value: "T", segments: [.degrees(0, span: 20), .degrees(-90, span: 20)]),
        .init(value: "U", segments: [.degrees(-90, span: 20), .degrees(0, span: 20), .degrees(90, span: 20)]),
        .init(value: "V", segments: [.degrees(-60, span: 30), .degrees(60, span: 20)]),
        .init(value: "W", segments: [.degrees(-60, span: 30), .degrees(60, span: 30), .degrees(-60, span: 30), .degrees(60, span: 30)]),
        .init(value: "X", segments: [.degrees(45, span: 30), .degrees(180, span: 20), .degrees(-45, span: 30)]),
        .init(value: "Z", segments: [.degrees(0, span: 20), .degrees(-135, span: 30), .degrees(0, span: 20)]),
        .init(value: "Left", segments: [.degrees(180, span: 35)]),
        .init(value: "Right", segments: [.degrees(0, span: 35)]),
        .init(value: "Left-Right", segments: [.degrees(180, span: 30), .degrees(0, span: 30)]),
        .init(value: "Right-Left", segments: [.degrees(0, span: 30), .degrees(180, span: 30)]),
        .init(value: "/ Down", segments: [.degrees(-120, span: 25)]),
        .init(value: "/ Up", segments: [.degrees(60, span: 25)]),
        .init(value: "\\ Down", segments: [.degrees(-60, span: 25)]),
        .init(value: "\\ Up", segments: [.degrees(120, span: 25)]),
        .init(value: "Up-Left", segments: [.degrees(90, span: 20), .degrees(180, span: 20)]),
        .init(value: "Up-Right", segments: [.degrees(90, span: 20), .degrees(0, span: 20)]),
        .init(value: "Left-Up", segments: [.degrees(180, span: 20), .degrees(90, span: 20)]),
        .init(value: "Right-Up", segments: [.degrees(0, span: 20), .degrees(90, span: 20)]),
    ]

    private var candidates = Self.templates.map { ScoredTemplate(template: $0) }
    private(set) var isCancelled = false

    mutating func reset() {
        candidates = Self.templates.map { ScoredTemplate(template: $0) }
        isCancelled = false
    }

    mutating func advance(angle: CGFloat) {
        let normalizedInput = normalizeAngle(Double(angle))
        var highestScore = -100_000.0

        for index in candidates.indices {
            var candidate = candidates[index]

            if let currentSegment = candidate.currentSegment,
               isWithin(normalizedInput, target: currentSegment.angle, span: currentSegment.span) {
                candidate.stepIndex += 1
            }

            if let matchedSegment = candidate.lastMatchedSegment {
                candidate.score += score(
                    normalizedInput,
                    target: matchedSegment.angle,
                    span: matchedSegment.span,
                    low: 0.5,
                    high: 1.0
                )

                let penalty = score(
                    normalizedInput,
                    target: oppositeAngle(for: matchedSegment.angle),
                    span: .pi - matchedSegment.span,
                    low: 0.1,
                    high: 1.5
                )
                candidate.score -= candidate.isComplete ? (2 * penalty) : penalty
            } else if let firstSegment = candidate.template.segments.first {
                candidate.score -= score(
                    normalizedInput,
                    target: oppositeAngle(for: firstSegment.angle),
                    span: .pi - firstSegment.span,
                    low: 0.1,
                    high: 1.5
                )
            }

            highestScore = max(highestScore, candidate.score)
            candidates[index] = candidate
        }

        if highestScore < -5 {
            isCancelled = true
        }
    }

    func bestMatch(for geometry: CharacterStrokeGeometry) -> RecognizedCharacter? {
        guard let bestCandidate = bestCandidate(for: geometry) else {
            return nil
        }

        guard bestCandidate.score >= 0 else {
            return nil
        }

        return RecognizedCharacter(value: bestCandidate.template.value, score: bestCandidate.score)
    }

    func bestGuess(for geometry: CharacterStrokeGeometry) -> String? {
        guard let bestCandidate = bestCandidate(for: geometry) else {
            return nil
        }

        return bestCandidate.score >= 0 ? bestCandidate.template.value : nil
    }

    func debugCandidates(for geometry: CharacterStrokeGeometry, limit: Int = 5) -> [CharacterRecognitionCandidateSnapshot] {
        candidates
            .map { candidate in
                CharacterRecognitionCandidateSnapshot(
                    value: candidate.template.value,
                    score: candidate.score,
                    matchedSegments: min(candidate.stepIndex, candidate.template.segments.count),
                    totalSegments: candidate.template.segments.count,
                    isComplete: candidate.isComplete,
                    isAcceptedByGeometry: geometry.accepts(candidate.template.value)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isComplete != rhs.isComplete {
                    return lhs.isComplete && !rhs.isComplete
                }
                if lhs.isAcceptedByGeometry != rhs.isAcceptedByGeometry {
                    return lhs.isAcceptedByGeometry && !rhs.isAcceptedByGeometry
                }
                if lhs.matchedSegments != rhs.matchedSegments {
                    return lhs.matchedSegments > rhs.matchedSegments
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map { $0 }
    }

    private func score(
        _ input: Double,
        target: Double,
        span: Double,
        low: Double,
        high: Double
    ) -> Double {
        guard span > 0 else { return 0 }
        let difference = shortestAngleDelta(from: input, to: target)
        guard abs(difference) <= span else { return 0 }

        let ratio = abs(difference / span)
        let gaussian = Self.gaussianValue(at: ratio)
        return (gaussian - Self.gaussianMin) * (high - low) / (Self.gaussianMax - Self.gaussianMin) + low
    }

    private func isWithin(_ input: Double, target: Double, span: Double) -> Bool {
        abs(shortestAngleDelta(from: input, to: target)) <= span
    }

    private func oppositeAngle(for angle: Double) -> Double {
        normalizeAngle(angle >= 0 ? (angle - .pi) : (angle + .pi))
    }

    private func shortestAngleDelta(from input: Double, to target: Double) -> Double {
        normalizeAngle(input - target)
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var value = angle
        while value <= -.pi {
            value += 2 * .pi
        }
        while value > .pi {
            value -= 2 * .pi
        }
        return value
    }

    private static func gaussianValue(at x: Double) -> Double {
        let coefficient = 1 / sqrt(2 * .pi * gaussianSigma * gaussianSigma)
        return coefficient * exp(-(x * x) / (2 * gaussianSigma * gaussianSigma))
    }

    private func bestCandidate(for geometry: CharacterStrokeGeometry) -> ScoredTemplate? {
        var bestCandidate: ScoredTemplate?

        for candidate in candidates where candidate.isComplete {
            if candidate.template.value == "H", bestCandidate?.template.value == "B" {
                continue
            }

            if candidate.template.value == "J", bestCandidate?.template.value == "Y" {
                continue
            }

            guard geometry.accepts(candidate.template.value) else {
                continue
            }

            if bestCandidate == nil || candidate.score > bestCandidate?.score ?? -.infinity {
                bestCandidate = candidate
            }
        }

        return bestCandidate
    }
}

private extension CharacterStrokeGeometry {
    func accepts(_ candidate: String) -> Bool {
        switch candidate {
        case "D":
            return normalizedVerticalDelta <= 0.2
        case "P":
            return normalizedVerticalDelta >= 0.2
        case "N":
            return normalizedVerticalDelta >= 0.3
        case "Y":
            return normalizedInverseVerticalDelta >= 0.5
        case "O":
            return normalizedVerticalDelta >= -0.2
        case "G":
            return normalizedVerticalDelta <= -0.2
        case "T", "F", "Left-Up", "Right-Up":
            return verticalSpan / horizontalSpan >= 0.2
        case "L", "Up-Left", "Up-Right":
            return horizontalSpan / verticalSpan >= 0.2
        default:
            return true
        }
    }
}

private struct CharacterTemplate {
    let value: String
    let segments: [AngleSpan]
}

private struct AngleSpan {
    let angle: Double
    let span: Double

    static func degrees(_ angle: Double, span: Double) -> AngleSpan {
        AngleSpan(angle: angle * .pi / 180, span: span * .pi / 180)
    }
}

private struct ScoredTemplate {
    let template: CharacterTemplate
    var stepIndex = 0
    var score = 0.0

    var currentSegment: AngleSpan? {
        guard stepIndex < template.segments.count else { return nil }
        return template.segments[stepIndex]
    }

    var lastMatchedSegment: AngleSpan? {
        guard stepIndex > 0 else { return nil }
        return template.segments[stepIndex - 1]
    }

    var isComplete: Bool {
        stepIndex >= template.segments.count
    }
}
