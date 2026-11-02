public struct DSThreshold: Equatable {
    public let warning: Double
    public let danger: Double

    public init(warning: Double, danger: Double) {
        self.warning = warning
        self.danger = danger
    }

    // 컨텍스트 사용률. 한도에 닿기 전부터 알린다.
    public static let context = DSThreshold(warning: 0.6, danger: 0.85)
    // 사용량(5시간, 주간). 한도가 거의 찰 때만 색을 바꾼다.
    public static let usage = DSThreshold(warning: 0.8, danger: 0.95)
}
