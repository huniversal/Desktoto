import SwiftUI

public enum DSMotion {
    // 진행 중과 대기로 바뀔 때 배경이 뚝 끊기지 않고 천천히 전환되는 시간
    public static let stateChange = Animation.easeInOut(duration: 1.5)
    public static let detail = Animation.easeInOut(duration: 0.25)
    // 값이 클수록 색 덩어리가 빨리 움직인다.
    public static let gradientPointSpeed = 0.3
    // 초당 팔레트 이동 칸 수. 0.1이면 색이 한 칸 바뀌는 데 약 10초가 걸린다.
    public static let gradientColorSpeed = 0.1
    public static let gradientFrameInterval = 1.0 / 30.0
}
