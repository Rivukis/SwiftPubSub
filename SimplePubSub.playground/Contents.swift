
// MARK: - Tests

class TestSubscriber {
    let disposer: Disposer

    init(disposer: Disposer) {
        self.disposer = disposer
    }

    func subscribeTo(_ observable: Observable<Int>) {
        observable.subscribe { _ in }.addTo(disposer)
    }
}

describe("Simple Pub Sub") {
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

                let disposable = subject.observable.subscribe { value in
                    secondSubValue = value
                }
                _ = subject.observable.subscribe { value in
                    thirdSubValue = value
                }

                disposable.dispose()

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
    }

    describe("Observable extensions") {
        var publisher: Publisher<String>!

        beforeEach {
            publisher = Publisher()
        }

        describe("map") {
            var firstSubValues: [Int]!
            var secondSubValues: [Int]!

            let emittedValue = "8"

            beforeEach {
                firstSubValues = []
                secondSubValues = []

                _ = publisher.observable.map{ Int($0) ?? -1 }.subscribe { value in
                    firstSubValues.append(value)
                }

                let secondDisposable = publisher.observable.map{ Int($0) ?? -1 }.subscribe { value in
                    secondSubValues.append(value)
                }

                secondDisposable.dispose()

                publisher.emit(emittedValue)
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

                _ = publisher.observable.filter{ $0 == emittedValue }.subscribe { value in
                    firstSubValues.append(value)
                }

                let secondDisposable = publisher.observable.filter{ $0 == emittedValue }.subscribe { value in
                    secondSubValues.append(value)
                }

                secondDisposable.dispose()

                publisher.emit("incorrect string")
                publisher.emit(emittedValue)
                publisher.emit("incorrect string")
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

    describe("Disposable") {
        var subject: Disposable!
        var publisher: Publisher<Int>!
        var valueEmitted: Int?

        beforeEach {
            publisher = Publisher()
            valueEmitted = nil

            subject = publisher.observable.subscribe { int in
                valueEmitted = int
            }
        }

        context("before disposing") {
            let expectedValue = 1

            beforeEach {
                publisher.emit(expectedValue)
            }

            it("should not dispose yet") {
                expect(valueEmitted).to(equal(expectedValue))
            }
        }

        context("after disposing") {
            beforeEach {
                subject.dispose()

                publisher.emit(2)
            }

            it("should dispose") {
                expect(valueEmitted).to(beNil())
            }
        }
    }

    describe("Disposer") {
        var testSubscriber: TestSubscriber?
        var publisher: Publisher<Int>!
        weak var weakDisposer: Disposer?

        beforeEach {
            let disposer = Disposer()
            weakDisposer = disposer
            testSubscriber = TestSubscriber(disposer: disposer)

            publisher = Publisher()

            testSubscriber?.subscribeTo(publisher.observable)
        }

        context("before releasing testSubscriber") {
            it("should not dispose yet") {
                expect(weakDisposer).toNot(beNil())
            }
        }

        context("after releasing testSubscriber") {
            beforeEach {
                testSubscriber = nil
            }

            it("should dispose") {
                expect(weakDisposer).to(beNil())
            }
        }
    }
}


// MARK: - Example Usage

/*

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

class StoreLocator {
    fileprivate func observable(forLocation location: Double) -> Observable<[Int]> {
        let publisher: Publisher<[Int]> = Publisher<[Int]>.rememberLastEmit()

        print("emitting")
        publisher.emit([Int(location) - 1, Int(location), Int(location) + 1])

//        publishers.append(publisher)

        return publisher.observable
    }
}

let location = Location()
let storeLocator = StoreLocator()

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

print("\nremoving third sub\n")
location.observable.removeSubscription(withID: mappedID)

location.emitLocations()

 */
