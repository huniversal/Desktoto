import Domain

/// 패널에 보여 줄 세션 순서. 승인 대기, 진행 중, 방금 끝난 세션, 나머지 순이고 같은 순위는 받은 순서를 지킨다.
enum PanelSessionSorter {
    static func sorted(_ sessions: [SessionInfo], finishedIDs: Set<String>) -> [SessionInfo] {
        sessions
            .enumerated()
            .sorted { lhs, rhs in
                let (lhsRank, rhsRank) = (rank(of: lhs.element, finishedIDs: finishedIDs), rank(of: rhs.element, finishedIDs: finishedIDs))
                return lhsRank != rhsRank ? lhsRank < rhsRank : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func rank(of session: SessionInfo, finishedIDs: Set<String>) -> Int {
        if session.isWaitingForUser { return 0 }
        if session.isRunning { return 1 }
        return finishedIDs.contains(session.id) ? 2 : 3
    }
}
