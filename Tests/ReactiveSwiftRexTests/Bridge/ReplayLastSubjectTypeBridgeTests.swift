import ReactiveSwift
import ReactiveSwiftRex
import SwiftRex
import XCTest

class ReplayLastSubjectTypeBridgeTests: XCTestCase {
    func testMutablePropertyToReplayLastSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")

        let property = MutableProperty<String>("no one cares 1")
        property.value = "no one cares 2"
        property.value = "current value"

        let sut = ReplayLastSubjectType(property: property)

        var round = 1
        _ = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                switch round {
                case 1:
                    XCTAssertEqual("current value", string)
                case 2:
                    XCTAssertEqual("test", string)
                    shouldCallClosureValue.fulfill()
                default:
                    XCTFail("called too many times")
                }
                round += 1
            }
        ))

        XCTAssertEqual(sut.value(), "current value")
        sut.subscriber.onValue("test")
        XCTAssertEqual(sut.value(), "test")

        wait(for: [shouldCallClosureValue], timeout: 0.1)
    }

    func testDefaultReplayLastSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")

        let sut = ReplayLastSubjectType.reactive(initialValue: "no one cares 1")
        sut.subscriber.onValue("no one cares 2")
        sut.subscriber.onValue("current value")

        var round = 1
        _ = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                switch round {
                case 1:
                    XCTAssertEqual("current value", string)
                case 2:
                    XCTAssertEqual("test", string)
                    shouldCallClosureValue.fulfill()
                default:
                    XCTFail("called too many times")
                }
                round += 1
            }
        ))

        XCTAssertEqual(sut.value(), "current value")
        sut.subscriber.onValue("test")
        XCTAssertEqual(sut.value(), "test")

        wait(for: [shouldCallClosureValue], timeout: 0.1)
    }

    func testDefaultReplayLastSubjectTypeMutate() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")

        let sut = ReplayLastSubjectType.reactive(initialValue: "no one cares 1")
        sut.subscriber.onValue("no one cares 2")
        sut.subscriber.onValue("current value")

        var round = 1
        _ = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                switch round {
                case 1:
                    XCTAssertEqual("current value", string)
                case 2:
                    XCTAssertEqual("test", string)
                case 3:
                    XCTAssertEqual("test 2", string)
                    shouldCallClosureValue.fulfill()
                default:
                    XCTFail("called too many times")
                }
                round += 1
            }
        ))

        XCTAssertEqual(sut.value(), "current value")

        sut.mutate { value in
            XCTAssertEqual("current value", value)
            value = "test"
        }
        XCTAssertEqual(sut.value(), "test")

        sut.mutate { value in
            XCTAssertEqual("test", value)
            value = "test 2"
        }
        XCTAssertEqual(sut.value(), "test 2")

        wait(for: [shouldCallClosureValue], timeout: 0.1)
    }
}
