import Foundation

/// How a query matched a candidate, from weakest to strongest.
public enum MatchTier: Int, Comparable, Sendable {
    case subsequence = 1, substring, wordInitials, wordPrefix, prefix, exact

    public static func < (lhs: MatchTier, rhs: MatchTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A match result. Compared by tier first, then by score (tighter, shorter candidates score higher).
public struct FuzzyMatch: Comparable, Sendable {
    public let tier: MatchTier
    public let score: Int

    public init(tier: MatchTier, score: Int) {
        self.tier = tier
        self.score = score
    }

    public static func < (lhs: FuzzyMatch, rhs: FuzzyMatch) -> Bool {
        lhs.tier != rhs.tier ? lhs.tier < rhs.tier : lhs.score < rhs.score
    }
}

public enum FuzzyMatcher {
    /// Matches `query` against `candidate`, case- and diacritic-insensitively. `nil` when it doesn't match.
    public static func match(_ query: String, in candidate: String) -> FuzzyMatch? {
        let q = Array(normalize(query))
        guard !q.isEmpty else { return nil }
        let c = Array(normalize(candidate))
        guard !c.isEmpty else { return nil }

        func result(_ tier: MatchTier, span: Int) -> FuzzyMatch {
            FuzzyMatch(tier: tier, score: 1000 - span - c.count)
        }

        if c == q { return result(.exact, span: q.count) }
        if c.starts(with: q) { return result(.prefix, span: q.count) }

        let starts = wordStarts(of: candidate, normalizedCount: c.count)
        if starts.dropFirst().contains(where: { c[$0...].starts(with: q) }) {
            return result(.wordPrefix, span: q.count)
        }

        let initials = starts.map { c[$0] }
        if q.count > 1, initials.starts(with: q) {
            return result(.wordInitials, span: q.count)
        }

        if contains(c, q) { return result(.substring, span: q.count) }

        if let span = tightestSubsequenceSpan(of: q, in: c) {
            return result(.subsequence, span: span)
        }
        return nil
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Indices (into the normalized character array) where words begin. Words split on separators and
    /// on lower→upper camel-case boundaries in the original string.
    private static func wordStarts(of original: String, normalizedCount: Int) -> [Int] {
        let separators: Set<Character> = [" ", "-", "_", ".", "·", "/", ":", "(", ")", "—", "–"]
        let chars = Array(original.trimmingCharacters(in: .whitespacesAndNewlines))
        // Folding can change length for exotic characters; fall back to separator-free single word then.
        guard chars.count == normalizedCount else { return [0] }
        var starts: [Int] = []
        for i in chars.indices {
            let ch = chars[i]
            if separators.contains(ch) { continue }
            if i == 0 || separators.contains(chars[i - 1]) {
                starts.append(i)
            } else if ch.isUppercase && chars[i - 1].isLowercase {
                starts.append(i)
            }
        }
        return starts.isEmpty ? [0] : starts
    }

    private static func contains(_ c: [Character], _ q: [Character]) -> Bool {
        guard q.count <= c.count else { return false }
        for i in 0...(c.count - q.count) where c[i] == q[0] && c[i..<(i + q.count)].elementsEqual(q) {
            return true
        }
        return false
    }

    /// Smallest window of `c` containing `q` as a subsequence, or nil.
    private static func tightestSubsequenceSpan(of q: [Character], in c: [Character]) -> Int? {
        var best: Int?
        for start in c.indices where c[start] == q[0] {
            var qi = 1
            var i = start + 1
            while qi < q.count, i < c.count {
                if c[i] == q[qi] { qi += 1 }
                i += 1
            }
            guard qi == q.count else { break } // later starts can't succeed either
            let span = i - start
            if best == nil || span < best! { best = span }
        }
        return best
    }
}
