import func Glibc.memcmp

public struct BinaryEncodedData {
	private struct Header {
		let capacity: Int
		var count: Int = 0

		init(capacity: Int) {
			self.capacity = capacity
		}
	}

	private final class Buffer : ManagedBuffer<Header, UInt8> {
		class func create(minimumCapacity: Int) -> Buffer {
			let storage = super.create(minimumCapacity: minimumCapacity) { buf in
				return Header(capacity: buf.capacity)
			}
			return storage as! Buffer
		}
	}

	private var buffer: Buffer

	public init(minimumCapacity: Int = 0) {
		buffer = Buffer.create(minimumCapacity: minimumCapacity)
	}

	public init(copyFrom: UnsafeRawPointer, count: Int) {
		self.init(minimumCapacity: count)
		withUnsafeMutableBufferRawPointer { $0.baseAddress!.copyBytes(from: copyFrom, count: count) }
		self.count = count
	}

	public init<C : Collection>(_ c: C) where C.Iterator.Element == UInt8 {
		let cont = ContiguousArray(c)
		self.init(minimumCapacity: cont.count)
		cont.withUnsafeBufferPointer { from in
			withUnsafeMutableBufferRawPointer { to in
				to.baseAddress!.copyBytes(from: UnsafeRawPointer(from.baseAddress!), count: cont.count)
			}
		}
		count = cont.count
	}

	public var capacity: Int {
		return buffer.header.capacity
	}

	public fileprivate(set) var count: Int {
		get { return buffer.header.count }
		set { buffer.header.count = newValue }
	}

	mutating func reserveCapacity(_ minimumCapacity: Int) {
		guard capacity < minimumCapacity else { return }
		detachBuffer(minimumCapacity: minimumCapacity)
	}

	fileprivate mutating func ensureUniqueStorage(minimumCapacity: Int) {
		if isKnownUniquelyReferenced(&buffer) {
			reserveCapacity(minimumCapacity)
		} else {
			detachBuffer(minimumCapacity: minimumCapacity)
		}
	}

	private mutating func detachBuffer(minimumCapacity: Int) {
		let newBuffer = Buffer.create(minimumCapacity: minimumCapacity)
		newBuffer.withUnsafeMutablePointerToElements { n in
			buffer.withUnsafeMutablePointerToElements { o in
				UnsafeMutableRawPointer(n).copyBytes(from: UnsafeRawPointer(o), count: count)
			}
		}
		newBuffer.header.count = count
		buffer = newBuffer
	}

	public func withUnsafeBufferRawPointer<R>(_ body: (UnsafeBufferRawPointer) throws -> R) rethrows -> R {
		return try buffer.withUnsafeMutablePointerToElements {
			return try body(UnsafeBufferRawPointer(start: UnsafeRawPointer($0), count: count))
		}
	}

	mutating func withUnsafeMutableBufferRawPointer<R>(_ body: (UnsafeMutableBufferRawPointer) throws -> R) rethrows -> R {
		return try buffer.withUnsafeMutablePointerToElements {
			return try body(UnsafeMutableBufferRawPointer(start: UnsafeMutableRawPointer($0), count: capacity))
		}
	}
}

public extension BinaryEncodedData {
	private func readWrapper<T>(at offset: inout Int, _ body: (inout UnsafeBufferRawPointer.Reader) throws -> T) rethrows -> T {
		return try withUnsafeBufferRawPointer { buffer in
			var reader = buffer.reader(offset: offset)
			defer { offset = reader.start - buffer.baseAddress! }
			return try body(&reader)
		}
	}

	func read<T : NativeBinaryEncoding>(_: T.Type, at offset: inout Int) throws -> T {
		return try readWrapper(at: &offset) { try $0.read(T.self) }
	}

	func read(_: VarUInt.Type, at offset: inout Int) throws -> UInt {
		return try readWrapper(at: &offset) { try $0.read(VarUInt.self) }
	}

	func read(_: BinaryEncodedData.Type, withSize: Int, at offset: inout Int) throws -> BinaryEncodedData {
		return try readWrapper(at: &offset) { try $0.read(BinaryEncodedData.self, withSize: withSize) }
	}

	func read<S : LengthItem>(_: BinaryEncodedData.Type, withSizeOf: S.Type, at offset: inout Int) throws -> BinaryEncodedData {
		return try readWrapper(at: &offset) { try $0.read(BinaryEncodedData.self, withSizeOf: S.self) }
	}

	func read(_: BinaryEncodedData.Type, withSizeOf: VarUInt.Type, at offset: inout Int) throws -> BinaryEncodedData {
		return try readWrapper(at: &offset) { try $0.read(BinaryEncodedData.self, withSizeOf: VarUInt.self) }
	}

	func read(_: String.Type, withSize: Int, at offset: inout Int) throws -> String {
		return try readWrapper(at: &offset) { try $0.read(String.self, withSize: withSize) }
	}

	func read<S : LengthItem>(_: String.Type, withSizeOf: S.Type, at offset: inout Int) throws -> String {
		return try readWrapper(at: &offset) { try $0.read(String.self, withSizeOf: S.self) }
	}

	func read(_: String.Type, withSizeOf: VarUInt.Type, at offset: inout Int) throws -> String {
		return try readWrapper(at: &offset) { try $0.read(String.self, withSizeOf: VarUInt.self) }
	}

	func read<T : SequenceItem>(arrayOf: T.Type, withSize: Int, at offset: inout Int) throws -> [T] {
		return try readWrapper(at: &offset) { try $0.read(arrayOf: T.self, withSize: withSize) }
	}

	func read<T : SequenceItem, S : LengthItem>(arrayOf: T.Type, withSizeOf: S.Type, at offset: inout Int) throws -> [T] {
		return try readWrapper(at: &offset) { try $0.read(arrayOf: T.self, withSizeOf: S.self) }
	}

	func read<T : SequenceItem>(arrayOf: T.Type, withSizeOf: VarUInt.Type, at offset: inout Int) throws -> [T] {
		return try readWrapper(at: &offset) { try $0.read(arrayOf: T.self, withSizeOf: VarUInt.self) }
	}
}

public extension BinaryEncodedData {
	private mutating func writeWrapper(at offset: inout Int, size: Int, body: (inout UnsafeMutableBufferRawPointer.Writer) throws -> Void) {
		precondition(offset <= count)
		ensureUniqueStorage(minimumCapacity: offset + size)
		withUnsafeMutableBufferRawPointer { buffer in
			var writer = buffer.writer(offset: offset)
			defer { offset = writer.start - buffer.baseAddress! }
			try! body(&writer)
		}
		if offset > count {
			count = offset
		}
	}

	mutating func write<T : NativeBinaryEncoding>(_ value: T, as: T.Type, at offset: inout Int) {
		writeWrapper(at: &offset, size: MemoryLayout<T>.size) { try $0.write(value, as: T.self) }
	}

	mutating func write(_ value: UInt, as: VarUInt.Type, at offset: inout Int) {
		writeWrapper(at: &offset, size: VarUInt.maxSize) { try $0.write(value, as: VarUInt.self) }
	}

	mutating func write(_ value: BinaryEncodedData, at offset: inout Int) {
		writeWrapper(at: &offset, size: value.count) { try $0.write(value) }
	}

	mutating func write<S : LengthItem>(_ value: BinaryEncodedData, withSizeOf: S.Type, at offset: inout Int) {
		writeWrapper(at: &offset, size: value.count) { try $0.write(value, withSizeOf: S.self) }
	}

	mutating func write(_ value: BinaryEncodedData, withSizeOf: VarUInt.Type, at offset: inout Int) {
		writeWrapper(at: &offset, size: value.count) { try $0.write(value, withSizeOf: VarUInt.self) }
	}

	mutating func write(_ value: String, as: String.Type, at offset: inout Int) {
		return write(value.utf8, asArrayOf: UTF8.CodeUnit.self, at: &offset)
	}

	mutating func write<S : LengthItem>(_ value: String, as: String.Type, withSizeOf: S.Type, at offset: inout Int) {
		return write(value.utf8, asArrayOf: UTF8.CodeUnit.self, withSizeOf: S.self, at: &offset)
	}

	mutating func write(_ value: String, as: String.Type, withSizeOf: VarUInt.Type, at offset: inout Int) {
		return write(value.utf8, asArrayOf: UTF8.CodeUnit.self, withSizeOf: VarUInt.self, at: &offset)
	}

	mutating func write<C : Collection>(_ value: C, asArrayOf: C.Iterator.Element.Type, at offset: inout Int)
		where C.Iterator.Element : SequenceItem {
		let size = numericCast(value.count) * MemoryLayout<C.Iterator.Element>.size
		writeWrapper(at: &offset, size: size) { try $0.write(value, asArrayOf: C.Iterator.Element.self) }
	}

	mutating func write<C : Collection, S : LengthItem>(_ value: C, asArrayOf: C.Iterator.Element.Type, withSizeOf: S.Type, at offset: inout Int)
		where C.Iterator.Element : SequenceItem {
		let size = MemoryLayout<S>.size + numericCast(value.count) * MemoryLayout<C.Iterator.Element>.size
		writeWrapper(at: &offset, size: size) { try $0.write(value, asArrayOf: C.Iterator.Element.self, withSizeOf: S.self) }
	}

	mutating func write<C : Collection>(_ value: C, asArrayOf: C.Iterator.Element.Type, withSizeOf: VarUInt.Type, at offset: inout Int)
		where C.Iterator.Element : SequenceItem {
		let size = VarUInt.maxSize + numericCast(value.count) * MemoryLayout<C.Iterator.Element>.size
		writeWrapper(at: &offset, size: size) { try $0.write(value, asArrayOf: C.Iterator.Element.self, withSizeOf: VarUInt.self) }
	}

	mutating func append<T : NativeBinaryEncoding>(_ value: T, as: T.Type) {
		var offset = count
		write(value, as: T.self, at: &offset)
	}

	mutating func append(_ value: UInt, as: VarUInt.Type) {
		var offset = count
		write(value, as: VarUInt.self, at: &offset)
	}

	mutating func append(_ value: BinaryEncodedData) {
		var offset = count
		write(value, at: &offset)
	}

	mutating func append<S : LengthItem>(_ value: BinaryEncodedData, withSizeOf: S.Type) {
		var offset = count
		return write(value, withSizeOf: S.self, at: &offset)
	}

	mutating func append(_ value: BinaryEncodedData, withSizeOf: VarUInt.Type) {
		var offset = count
		return write(value, withSizeOf: VarUInt.self, at: &offset)
	}

	mutating func append(_ value: String, as: String.Type) {
		var offset = count
		return write(value, as: String.self, at: &offset)
	}

	mutating func append<S : LengthItem>(_ value: String, as: String.Type, withSizeOf: S.Type) {
		var offset = count
		return write(value, as: String.self, withSizeOf: S.self, at: &offset)
	}

	mutating func append(_ value: String, as: String.Type, withSizeOf: VarUInt.Type) {
		var offset = count
		return write(value, as: String.self, withSizeOf: VarUInt.self, at: &offset)
	}

	mutating func append<C : Collection>(_ value: C, asArrayOf: C.Iterator.Element.Type)
		where C.Iterator.Element : SequenceItem {
		var offset = count
		write(value, asArrayOf: C.Iterator.Element.self, at: &offset)
	}

	mutating func append<C : Collection, S : LengthItem>(_ value: C, asArrayOf: C.Iterator.Element.Type, withSizeOf: S.Type)
		where C.Iterator.Element : SequenceItem {
		var offset = count
		write(value, asArrayOf: C.Iterator.Element.self, withSizeOf: S.self, at: &offset)
	}

	mutating func append<C : Collection>(_ value: C, asArrayOf: C.Iterator.Element.Type, withSizeOf: VarUInt.Type)
		where C.Iterator.Element : SequenceItem {
		var offset = count
		write(value, asArrayOf: C.Iterator.Element.self, withSizeOf: VarUInt.self, at: &offset)
	}
}

extension BinaryEncodedData : Equatable {
	public static func ==(lhs: BinaryEncodedData, rhs: BinaryEncodedData) -> Bool {
		if lhs.count != rhs.count { return false }
		return lhs.withUnsafeBufferRawPointer { lb in
			return rhs.withUnsafeBufferRawPointer { rb in
				if lb.baseAddress == rb.baseAddress { return true }
				return memcmp(lb.baseAddress!, rb.baseAddress!, lb.count) == 0
			}
		}
	}
}

extension BinaryEncodedData : CustomDebugStringConvertible {
	public var debugDescription: String {
		let bytes: String = withUnsafeBufferRawPointer {
			let data = UnsafeBufferPointer<UInt8>(start: $0.baseAddress?.assumingMemoryBound(to: UInt8.self), count: count)
			return data.map { $0 > 0xf ? String($0, radix: 16) : "0" + String($0, radix: 16) }.joined(separator: " ")
		}
		return "BinaryEncodedData([\(count)/\(capacity)]<\(bytes)>)"
	}
}
