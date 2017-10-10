
// MARK: - Tests

describe("Publisher") {
    var subject: Publisher<String>!

    beforeEach {
        subject = Publisher()
    }

    describe("emitting elements") {
        var firstSubValue: String?
        var secondSubValue: String?
        var thirdSubValue: String?

        let emittedValue = "i was sent"

        beforeEach {
            _ = subject.observable.subscribe { value in
                firstSubValue = value
            }
            let id = subject.observable.subscribe { value in
                secondSubValue = value
            }
            _ = subject.observable.subscribe { value in
                thirdSubValue = value
            }

            subject.observable.removeSubscription(withID: id)

            subject.emit(emittedValue)
        }

        it("should emit element to all subscribers") {
            expect(firstSubValue).to(equal(emittedValue))
            expect(thirdSubValue).to(equal(emittedValue))
        }

        it("should NOT emit to removed subscribers") {
            expect(secondSubValue).to(beNil())
        }
    }

    describe("map") {
        var firstSubValues: [Int]!
        var secondSubValues: [Int]!

        let emittedValue = "8"

        beforeEach {
            firstSubValues = []
            secondSubValues = []

            _ = subject.observable.map{ Int($0) ?? -1 }.subscribe { value in
                firstSubValues.append(value)
            }
            let secondID = subject.observable.map{ Int($0) ?? -1 }.subscribe { value in
                secondSubValues.append(value)
            }

            subject.observable.removeSubscription(withID: secondID)

            subject.emit(emittedValue)
        }

        it("should emit mapped element") {
            expect(firstSubValues).to(contain(8))
        }

        it("should NOT emit to removed subscribers") {
            expect(secondSubValues).to(beEmpty())
        }
    }

    describe("filter") {
        var firstSubValues: [String]!
        var secondSubValues: [String]!

        let emittedValue = "i was sent"

        beforeEach {
            firstSubValues = []
            secondSubValues = []

            _ = subject.observable.filter{ $0 == emittedValue }.subscribe { value in
                firstSubValues.append(value)
            }
            let secondID = subject.observable.filter{ $0 == emittedValue }.subscribe { value in
                secondSubValues.append(value)
            }

            subject.observable.removeSubscription(withID: secondID)

            subject.emit("incorrect string")
            subject.emit(emittedValue)
            subject.emit("incorrect string")
        }

        it("should only emit element when filter predicate returns true") {
            expect(firstSubValues).to(haveCount(1))
            expect(firstSubValues[0]).to(equal(emittedValue))
        }

        it("should NOT emit to removed subscribers") {
            expect(secondSubValues).to(beEmpty())
        }
    }
}



// MARK: - Example Usage

class Location {
    private let publisher: Publisher<Double> = Publisher()

    internal var observable: Observable<Double> {
        return publisher.observable
    }

    fileprivate func emitLocations() {
        publisher.emit(1.9)
        publisher.emit(5.9)
        publisher.emit(3.9)
        publisher.emit(7.9)

    }
}

let location = Location()

_ = location.observable.subscribe { _ in
    print("")
}

_ = location.observable.subscribe { (double) in
    print("first sub", double)
}

_ = location.observable.subscribe { (double) in
    print("second sub", double)
}

let mappedID = location.observable.map{ "\"\($0)\"" }.subscribe { (double) in
    print("third sub - mapped", double)
}

_ = location.observable.map{ "\"\($0)\"" }.subscribe { (double) in
    print("other mapped sub - mapped", double)
}

_ = location.observable.filter { $0 > 5 }.subscribe { double in
    print("fourth sub - filtered", double)
}

let filterMappedID = location.observable
    .filter{ $0 > 5 }
    .map{ "I'm a string now: \($0)" }.subscribe { value in
    print("fourth sub - filtered", value)
}

//location.emitLocations()
//
//print("\nremoving third sub\n")
//location.observable.removeSubscription(withID: mappedID)
//
//location.emitLocations()
