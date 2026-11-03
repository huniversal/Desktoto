import DesignSystem
import Domain
import Foundation
import Observation

// 패널이 그릴 값을 보관한다. 표시 설정과 현재 시각은 앱 조립 쪽이 넣어 준다.
@MainActor
@Observable
public final class SessionPanelModel {
    public var sessions: [SessionInfo] = []
    // 컨텍스트 목록 위에 고정해서 보여주는, AI별 5시간과 주간 사용량. 비어 있으면 사용량 카드를 그리지 않는다.
    public var usages: [ToolUsage] = []
    // 패널을 열기 전에 끝난, 아직 확인하지 않은 세션 id
    public var finishedIDs: Set<String> = []
    // 마우스가 올라와 있는 세션 id. 이 줄만 모델과 토큰 수가 펼쳐진다.
    public var hoveredID: String?
    public var showsUsage = true
    public var showsContext = true
    public var colorMode: ColorMode = .white
    public var glassStyle: GlassStyle = .regular
    // 남은 시간과 낡은 값 문구의 기준 시각
    public var now: Date
    // 줄을 눌렀을 때 앱이 그 세션을 열도록 하는 연결. 화면 갱신과는 무관해서 관찰하지 않는다.
    @ObservationIgnored public var onOpenSession: (@MainActor (SessionInfo) -> Void)?

    public init(now: Date) {
        self.now = now
    }

    // 방금 끝난 줄: 진행 중이 아니고 확인하지 않은 완료 목록에 있다.
    func isJustFinished(_ session: SessionInfo) -> Bool {
        !session.isRunning && finishedIDs.contains(session.id)
    }

    func changeHover(of session: SessionInfo, isInside: Bool) {
        if isInside {
            hoveredID = session.id
        } else if hoveredID == session.id {
            hoveredID = nil
        }
    }

    // 열 곳이 있는 세션만 연다.
    func open(_ session: SessionInfo) {
        if session.canOpen { onOpenSession?(session) }
    }
}
