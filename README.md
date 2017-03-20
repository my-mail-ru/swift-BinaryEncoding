# BinaryEncoding

![Swift: 3.0](https://img.shields.io/badge/Swift-3.0-orange.svg)
![OS: Linux](https://img.shields.io/badge/OS-Linux-brightgreen.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

The BinaryEncoding library is designed to simplify encoding/decoding of native Swift types and their sequences into binary data buffers.

Supported types are: `Int`, `UInt`, `Int*`, `UInt*`, `Float`, `Double`, `VarUInt`, `String` and various collections of native numbers.
Native numbers are encoded as is, using architecture-dependent representations, strings are encoded in UTF-8.
`VarUInt` encoding is equal to `w` format of Perl `pack` function.

## Requirements

Swift 3.0.1

## Design

The library provides managed buffers of raw bytes with copy-on-write behaviour.

### BinaryEncodedData

Has various `read`, `write` and `append` methods for all supported types:

```swift
	init(minimumCapacity: Int = 0)

	func read<T : NativeBinaryEncoding>(_: T.Type, at offset: inout Int) throws -> T
	func read(_: VarUInt.Type, at offset: inout Int) throws -> UInt
	func read(_: BinaryEncodedData.Type, withSize: Int, at offset: inout Int) throws -> BinaryEncodedData
	func read<S : LengthItem>(_: BinaryEncodedData.Type, withSizeOf: S.Type, at offset: inout Int) throws -> BinaryEncodedData
	func read(_: BinaryEncodedData.Type, withSizeOf: VarUInt.Type, at offset: inout Int) throws -> BinaryEncodedData
	func read(_: String.Type, withSize: Int, at offset: inout Int) throws -> String
	func read<S : LengthItem>(_: String.Type, withSizeOf: S.Type, at offset: inout Int) throws -> String
	func read(_: String.Type, withSizeOf: VarUInt.Type, at offset: inout Int) throws -> String
	func read<T : SequenceItem>(arrayOf: T.Type, withSize: Int, at offset: inout Int) throws -> [T]
	func read<T : SequenceItem, S : LengthItem>(arrayOf: T.Type, withSizeOf: S.Type, at offset: inout Int) throws -> [T]
	func read<T : SequenceItem>(arrayOf: T.Type, withSizeOf: VarUInt.Type, at offset: inout Int) throws -> [T]

	mutating func write<T : NativeBinaryEncoding>(_ value: T, as: T.Type, at offset: inout Int)
	mutating func write(_ value: UInt, as: VarUInt.Type, at offset: inout Int)
	mutating func write(_ value: BinaryEncodedData, at offset: inout Int)
	mutating func write<S : LengthItem>(_ value: BinaryEncodedData, withSizeOf: S.Type, at offset: inout Int)
	mutating func write(_ value: BinaryEncodedData, withSizeOf: VarUInt.Type, at offset: inout Int)
	mutating func write(_ value: String, as: String.Type, at offset: inout Int)
	mutating func write<S : LengthItem>(_ value: String, as: String.Type, withSizeOf: S.Type, at offset: inout Int)
	mutating func write(_ value: String, as: String.Type, withSizeOf: VarUInt.Type, at offset: inout Int)
	mutating func write<C : Collection>(_ value: C, asArrayOf: C.Iterator.Element.Type, at offset: inout Int)
		where C.Iterator.Element : SequenceItem
	mutating func write<C : Collection, S : LengthItem>(_ value: C, asArrayOf: C.Iterator.Element.Type, withSizeOf: S.Type, at offset: inout Int)
		where C.Iterator.Element : SequenceItem
	mutating func write<C : Collection>(_ value: C, asArrayOf: C.Iterator.Element.Type, withSizeOf: VarUInt.Type, at offset: inout Int)
		where C.Iterator.Element : SequenceItem

	mutating func append... // same as write but without parameter (at:)
```

Usage examples can be found in [tests](Tests/BinaryEncodingTests/Data.swift).

### UnsafeRawBufferPointer.Reader and UnsafeMutableRawBufferPointer.Writer

These interfaces are unsafe. If you want to use them for effeciency you can find enough infromation in the source code.
