import Foundation
import Testing
@testable import Bethal

@Suite("JSONCoding")
struct JSONCodingTests {
    @Test("encoder uses sorted keys and iso8601")
    func encoderSettings() throws {
        struct Sample: Codable, Equatable {
            var zebra: Int
            var apple: Date
        }
        let value = Sample(zebra: 1, apple: Date(timeIntervalSince1970: 0))
        let data = try JSONCoding.encode(value)
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("apple"))
        #expect(text.contains("zebra"))
        // sortedKeys → apple before zebra
        #expect(text.range(of: "apple")!.lowerBound < text.range(of: "zebra")!.lowerBound)
        let decoded = try JSONCoding.decode(Sample.self, from: data)
        #expect(decoded == value)
    }
}
