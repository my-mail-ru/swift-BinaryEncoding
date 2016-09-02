import XCTest
import BinaryEncoding

class DataTests : XCTestCase {
	static var allTests: [(String, (DataTests) -> () throws -> Void)] {
		return [
			("testInt", testInt),
			("testVarUInt", testVarUInt),
			("testString", testString),
			("testArray", testArray),
		]
	}

	func testInt() throws {
		var data = BinaryEncodedData()
		data.append(10, as: Int32.self)
		data.append(150, as: UInt8.self)
		data.append(200, as: VarUInt.self)
		data.append(-10, as: Int64.self)
		XCTAssertEqual(data, BinaryEncodedData([10, 0, 0, 0, 150, 0x81, 0x48, 246, 255, 255, 255, 255, 255, 255, 255]))
		var i = 0
		XCTAssertEqual(try data.read(Int32.self, at: &i), 10)
		XCTAssertEqual(try data.read(UInt8.self, at: &i), 150)
		XCTAssertEqual(try data.read(VarUInt.self, at: &i), 200)
		XCTAssertEqual(try data.read(Int64.self, at: &i), -10)
	}

	func testVarUInt() throws {
		var data = BinaryEncodedData()
		data.append(10000000000000000000, as: VarUInt.self)
		XCTAssertEqual(data, BinaryEncodedData([0x81, 0x8a, 0xe3, 0xc8, 0xe0, 0xc8, 0xcf, 0xa0, 0x80, 0x00]))
		var i = 0
		XCTAssertEqual(try data.read(VarUInt.self, at: &i), 10000000000000000000)
	}

	func testString() throws {
		var data = BinaryEncodedData()
		data.append("Строченька", as: String.self, withSizeOf: VarUInt.self)
		data.append("String", as: String.self, withSizeOf: VarUInt.self)
		XCTAssertEqual(data, BinaryEncodedData([20, 208, 161, 209, 130, 209, 128, 208, 190, 209, 135, 208, 181, 208, 189, 209, 140, 208, 186, 208, 176, 6, 83, 116, 114, 105, 110, 103]))
		var i = 0
		XCTAssertEqual(try data.read(String.self, withSizeOf: VarUInt.self, at: &i), "Строченька")
		XCTAssertEqual(try data.read(String.self, withSizeOf: VarUInt.self, at: &i), "String")
	}

	func testArray() throws {
		var data = BinaryEncodedData()
		data.append([10, -10, 300], asArrayOf: Int32.self, withSizeOf: VarUInt.self)
		data.append(ContiguousArray([1, 15, 30]), asArrayOf: UInt8.self, withSizeOf: VarUInt.self)
		XCTAssertEqual(data, BinaryEncodedData([12, 10, 0, 0, 0, 246, 255, 255, 255, 44, 1, 0, 0, 3, 1, 15, 30]))
		var i = 0
		XCTAssertEqual(try data.read(arrayOf: Int32.self, withSizeOf: VarUInt.self, at: &i), [10, -10, 300])
		XCTAssertEqual(try data.read(arrayOf: UInt8.self, withSizeOf: VarUInt.self, at: &i), [1, 15, 30])
	}
}
