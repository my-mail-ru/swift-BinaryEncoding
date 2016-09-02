public enum BinaryEncodingError : Error {
	case bufferIsTooShort
	case varintIsTooLong
	case stringIsNotUTF8
}

public protocol NativeBinaryEncoding {}

extension Int : NativeBinaryEncoding {}
extension Int8 : NativeBinaryEncoding {}
extension Int16 : NativeBinaryEncoding {}
extension Int32 : NativeBinaryEncoding {}
extension Int64 : NativeBinaryEncoding {}

extension UInt : NativeBinaryEncoding {}
extension UInt8 : NativeBinaryEncoding {}
extension UInt16 : NativeBinaryEncoding {}
extension UInt32 : NativeBinaryEncoding {}
extension UInt64 : NativeBinaryEncoding {}

extension Float : NativeBinaryEncoding {}
extension Double : NativeBinaryEncoding {}

public struct VarUInt {
	static let maxSize = MemoryLayout<UInt>.size * 8 / 7 + 1
}

public typealias LengthItem = NativeBinaryEncoding & UnsignedInteger
public typealias SequenceItem = NativeBinaryEncoding
