import XCTest

@testable import BinaryEncodingTests

var tests = [XCTestCaseEntry]()
tests += [testCase(DataTests.allTests)]
XCTMain(tests)
