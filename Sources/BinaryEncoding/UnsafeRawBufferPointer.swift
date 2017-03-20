extension UnsafeRawBufferPointer {
	public func reader(offset: Int = 0) -> Reader {
		precondition(offset < count)
		return Reader(start: baseAddress! + offset, end: baseAddress! + count)
	}

	public struct Reader {
		var start: UnsafeRawPointer
		let end: UnsafeRawPointer

		public var count: Int {
			return end - start
		}

		public mutating func read<T : NativeBinaryEncoding>(_: T.Type) throws -> T {
			guard start + MemoryLayout<T>.size <= end else { throw BinaryEncodingError.bufferIsTooShort }
			let value = start.assumingMemoryBound(to: T.self).pointee
			start += MemoryLayout<T>.size
			return value
		}

		public mutating func read(_: VarUInt.Type) throws -> UInt {
			var value: UInt = 0
			for _ in (0..<VarUInt.maxSize) {
				guard start < end else { throw BinaryEncodingError.bufferIsTooShort }
				let v = start.assumingMemoryBound(to: UInt8.self).pointee
				start += 1
				value = (value << 7) | UInt(v & 0x7f)
				if v & 0x80 == 0 {
					return value
				}
			}
			throw BinaryEncodingError.varintIsTooLong
		}

		public mutating func read(_: UnsafeRawBufferPointer.Type, withSize: Int) throws -> UnsafeRawBufferPointer {
			guard start + withSize <= end else { throw BinaryEncodingError.bufferIsTooShort }
			defer { start += withSize }
			return UnsafeRawBufferPointer(start: start, count: withSize)
		}

		public mutating func read<S : LengthItem>(_: UnsafeRawBufferPointer.Type, withSizeOf: S.Type) throws -> UnsafeRawBufferPointer {
			let size = try read(S.self)
			return try read(UnsafeRawBufferPointer.self, withSize: numericCast(size))
		}

		public mutating func read(_: UnsafeRawBufferPointer.Type, withSizeOf: VarUInt.Type) throws -> UnsafeRawBufferPointer {
			let size = try read(VarUInt.self)
			return try read(UnsafeRawBufferPointer.self, withSize: Int(size))
		}

		public mutating func read(_: BinaryEncodedData.Type, withSize: Int) throws -> BinaryEncodedData {
			guard start + withSize <= end else { throw BinaryEncodingError.bufferIsTooShort }
			defer { start += withSize }
			return BinaryEncodedData(copyFrom: start, count: withSize)
		}

		public mutating func read<S : LengthItem>(_: BinaryEncodedData.Type, withSizeOf: S.Type) throws -> BinaryEncodedData {
			let size = try read(S.self)
			return try read(BinaryEncodedData.self, withSize: numericCast(size))
		}

		public mutating func read(_: BinaryEncodedData.Type, withSizeOf: VarUInt.Type) throws -> BinaryEncodedData {
			let size = try read(VarUInt.self)
			return try read(BinaryEncodedData.self, withSize: Int(size))
		}

		public mutating func read(_: String.Type, withSize: Int) throws -> String {
			guard start + withSize <= end else { throw BinaryEncodingError.bufferIsTooShort }
			defer { start += withSize }
			let utf8buf = UnsafeBufferPointer(start: start.assumingMemoryBound(to: UTF8.CodeUnit.self), count: withSize)
			guard let string = String._fromCodeUnitSequence(UTF8.self, input: utf8buf)
				else { throw BinaryEncodingError.stringIsNotUTF8 }
			return string
		}

		public mutating func read<S : LengthItem>(_: String.Type, withSizeOf: S.Type) throws -> String {
			let size = try read(S.self)
			return try read(String.self, withSize: numericCast(size))
		}

		public mutating func read(_: String.Type, withSizeOf: VarUInt.Type) throws -> String {
			let size = try read(VarUInt.self)
			return try read(String.self, withSize: Int(size))
		}

		public mutating func read<E : SequenceItem>(arrayOf: E.Type, withSize: Int) throws -> [E] {
			guard start + withSize <= end else { throw BinaryEncodingError.bufferIsTooShort }
			defer { start += withSize }
			return [E](UnsafeBufferPointer(start: start.assumingMemoryBound(to: E.self), count: withSize / MemoryLayout<E>.size))
		}

		public mutating func read<E : SequenceItem, S : LengthItem>(arrayOf: E.Type, withSizeOf: S.Type) throws -> [E] {
			let size = try read(S.self)
			return try read(arrayOf: E.self, withSize: numericCast(size))
		}

		public mutating func read<E : SequenceItem>(arrayOf: E.Type, withSizeOf: VarUInt.Type) throws -> [E] {
			let size = try read(VarUInt.self)
			return try read(arrayOf: E.self, withSize: Int(size))
		}
	}
}

extension UnsafeMutableRawBufferPointer {
	public func writer(offset: Int = 0) -> Writer {
		precondition(offset < count)
		return Writer(start: baseAddress! + offset, end: baseAddress! + count)
	}

	public struct Writer {
		var start: UnsafeMutableRawPointer
		let end: UnsafeMutableRawPointer

		public var count: Int {
			return end - start
		}

		public mutating func write<T : NativeBinaryEncoding>(_ value: T, as: T.Type) throws {
			guard start + MemoryLayout<T>.size <= end else { throw BinaryEncodingError.bufferIsTooShort }
			start.assumingMemoryBound(to: T.self).pointee = value
			start += MemoryLayout<T>.size
		}

		public mutating func write(_ value: UInt, as: VarUInt.Type) throws {
			var buf: (UInt, UInt) = (0, 0) // is there a better way exist?
			try withUnsafeMutablePointer(to: &buf) {
				let s = UnsafeMutableRawPointer($0)
				var v = value
				let e = s + MemoryLayout<(UInt, UInt)>.size
				var p = e - 1
				p.assumingMemoryBound(to: UInt8.self).pointee = UInt8(v & 0x7f)
				v >>= 7
				while v != 0 {
					p -= 1
					p.assumingMemoryBound(to: UInt8.self).pointee = UInt8(v & 0x7f) | 0x80
					v >>= 7
				}
				let size = e - p
				guard start + size <= end else { throw BinaryEncodingError.bufferIsTooShort }
				start.copyBytes(from: p, count: size)
				start += size
			}
		}

		public mutating func write(_ value: UnsafeRawBufferPointer) throws {
			guard start + value.count <= end else { throw BinaryEncodingError.bufferIsTooShort }
			start.copyBytes(from: value.baseAddress!, count: value.count)
			start += value.count
		}

		public mutating func write<S : LengthItem>(_ value: UnsafeRawBufferPointer, withSizeOf: S.Type) throws {
			try write(numericCast(value.count), as: S.self)
			try write(value)
		}

		public mutating func write(_ value: UnsafeRawBufferPointer, withSizeOf: VarUInt.Type) throws {
			try write(UInt(value.count), as: VarUInt.self)
			try write(value)
		}

		public mutating func write(_ value: BinaryEncodedData) throws {
			try value.withUnsafeBytes { try write($0) }
		}

		public mutating func write<S : LengthItem>(_ value: BinaryEncodedData, withSizeOf: S.Type) throws {
			try write(numericCast(value.count), as: S.self)
			try write(value)
		}

		public mutating func write(_ value: BinaryEncodedData, withSizeOf: VarUInt.Type) throws {
			try write(UInt(value.count), as: VarUInt.self)
			try write(value)
		}

		public mutating func write(_ value: String, as: String.Type) throws {
			try write(value.utf8, asArrayOf: UTF8.CodeUnit.self)
		}

		public mutating func write<S : LengthItem>(_ value: String, as: String.Type, withSizeOf: S.Type) throws {
			try write(value.utf8, asArrayOf: UTF8.CodeUnit.self, withSizeOf: S.self)
		}

		public mutating func write(_ value: String, as: String.Type, withSizeOf: VarUInt.Type) throws {
			try write(value.utf8, asArrayOf: UTF8.CodeUnit.self, withSizeOf: VarUInt.self)
		}

		public mutating func write<C : Collection>(_ value: C, asArrayOf: C.Iterator.Element.Type) throws
			where C.Iterator.Element : NativeBinaryEncoding {
			try ContiguousArray(value).withUnsafeBufferPointer {
				let size = $0.count * MemoryLayout<C.Iterator.Element>.size
				guard start + size <= end else { throw BinaryEncodingError.bufferIsTooShort }
				start.copyBytes(from: UnsafeRawPointer($0.baseAddress!), count: size)
				start += size
			}
		}

		public mutating func write<C : Collection, S : LengthItem>(_ value: C, asArrayOf: C.Iterator.Element.Type, withSizeOf: S.Type) throws
			where C.Iterator.Element : NativeBinaryEncoding {
			try ContiguousArray(value).withUnsafeBufferPointer {
				let size = $0.count * MemoryLayout<C.Iterator.Element>.size
				guard start + MemoryLayout<S>.size + size <= end else { throw BinaryEncodingError.bufferIsTooShort }
				start.assumingMemoryBound(to: S.self).pointee = numericCast(size)
				start += MemoryLayout<S>.size
				start.copyBytes(from: UnsafeRawPointer($0.baseAddress!), count: size)
				start += size
			}
		}

		public mutating func write<C : Collection>(_ value: C, asArrayOf: C.Iterator.Element.Type, withSizeOf: VarUInt.Type) throws
			where C.Iterator.Element : NativeBinaryEncoding {
			try ContiguousArray(value).withUnsafeBufferPointer {
				let size = $0.count * MemoryLayout<C.Iterator.Element>.size
				try write(UInt(size), as: VarUInt.self)
				guard start + size <= end else { throw BinaryEncodingError.bufferIsTooShort }
				start.copyBytes(from: UnsafeRawPointer($0.baseAddress!), count: size)
				start += size
			}
		}
	}
}
