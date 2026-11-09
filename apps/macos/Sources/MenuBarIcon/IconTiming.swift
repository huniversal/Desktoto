import Foundation

/// 프레임 수와 갱신 주기. 근거는 docs/reverse/menubar-icon.md의 "갱신 주기와 24fps의 근거"에 있다.
public enum IconTiming {
    /// 달리기 한 바퀴의 프레임 수. 3의 배수여야 다리 교대가 한 바퀴 끝에서 어긋나지 않는다(교대 횟수가 짝수).
    public static let runningFrameCount = 24
    /// 메뉴바 이미지를 바꿀 때마다 시스템이 스냅샷을 다시 만들어서, 초당 24번으로 제한한다.
    public static let runningFrameInterval: TimeInterval = 1.0 / 24.0
    public static let sleepFrameCount = 6
    public static let sleepFrameInterval: TimeInterval = 0.6
    public static let fireworkFrameCount = 24
    /// 표정(깜빡임, 하품 등)을 확인하는 주기. 표정이 바뀔 때만 이미지를 바꾸므로 메뉴바 갱신은 늘지 않는다.
    public static let behaviorInterval: TimeInterval = 0.05
    /// 시선이 목표를 따라가는 주기. 달리기와 같은 초당 24번이다.
    public static let gazeFrameInterval: TimeInterval = 1.0 / 24.0
}

/// 프레임 번호를 0 이상 count 미만으로 감싼다. 음수도 안전하게 처리한다.
func wrapFrameIndex(_ index: Int, count: Int) -> Int {
    ((index % count) + count) % count
}
