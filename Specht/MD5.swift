import Foundation
import CommonCrypto

class MD5 {
    static func string(_ s: String) -> String {
        let strData = s.data(using: String.Encoding.utf8)!
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        var result = [UInt8](count: digestLen, repeatedValue: 0)

        CC_MD5(strData.bytes, CC_LONG(strData.length), &result)

        return hexString(result)
    }

    static func hexString(_ result: [UInt8]) -> String {
        let hash = NSMutableString(capacity: result.count * 2)
        for i in 0..<result.count {
            hash.appendFormat("%02x", result[i])
        }

        return String(stringLiteral: hash as String)
    }
}
