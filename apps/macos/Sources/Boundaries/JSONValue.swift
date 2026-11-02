import Foundation

/// 기록 한 줄이나 설정 파일을 해석한 JSON 값. actor 사이에 넘길 수 있도록 `Sendable`이다.
public enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// 객체가 아니거나 키가 없으면 nil이다.
    public subscript(key: String) -> JSONValue? {
        guard case .object(let fields) = self else { return nil }
        return fields[key]
    }

    public var stringValue: String? {
        guard case .string(let text) = self else { return nil }
        return text
    }

    /// 정수로 떨어지는 숫자만 돌려준다.
    public var intValue: Int? {
        guard case .number(let value) = self, value == value.rounded(), abs(value) < 9_007_199_254_740_992 else { return nil }
        return Int(value)
    }

    public var arrayValue: [JSONValue]? {
        guard case .array(let items) = self else { return nil }
        return items
    }

    public var objectValue: [String: JSONValue]? {
        guard case .object(let fields) = self else { return nil }
        return fields
    }

    /// JSON 객체 하나를 해석한다. 객체가 아니거나 형식이 깨졌으면 nil이다.
    public static func parseObject(from data: Data) -> JSONValue? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return JSONValue(jsonObject: object)
    }

    private init?(jsonObject: Any) {
        switch jsonObject {
        case is NSNull:
            self = .null
        case let number as NSNumber:
            // NSNumber는 Bool로도 변환되므로 CoreFoundation 타입으로 불리언을 먼저 가른다.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        case let text as String:
            self = .string(text)
        case let items as [Any]:
            self = .array(items.compactMap { JSONValue(jsonObject: $0) })
        case let fields as [String: Any]:
            self = .object(fields.compactMapValues { JSONValue(jsonObject: $0) })
        default:
            return nil
        }
    }
}
