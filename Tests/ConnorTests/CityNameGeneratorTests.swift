import XCTest
@testable import Connor

final class CityNameGeneratorTests: XCTestCase {
    var generator: CityNameGenerator!

    override func setUp() {
        super.setUp()
        generator = CityNameGenerator()
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    func testAllCityNamesNotEmpty() {
        XCTAssertFalse(generator.allCityNames.isEmpty)
        XCTAssertGreaterThan(generator.allCityNames.count, 50)
    }

    func testGenerateUniqueNameReturnsValidCity() {
        let name = generator.generateUniqueName(excluding: [], existingNames: [])
        XCTAssertTrue(generator.allCityNames.contains(name))
    }

    func testGenerateUniqueNameExcludesRecentlyUsed() {
        // Exclude most cities
        let excludedCities = Array(generator.allCityNames.prefix(generator.allCityNames.count - 1))
        let name = generator.generateUniqueName(excluding: excludedCities, existingNames: [])

        // Should return the one city not excluded
        XCTAssertFalse(excludedCities.contains(name))
    }

    func testGenerateUniqueNameExcludesExistingNames() {
        let existingNames = ["Tokyo", "Paris", "Berlin"]
        let name = generator.generateUniqueName(excluding: [], existingNames: existingNames)

        XCTAssertFalse(existingNames.contains(name))
    }

    func testGenerateUniqueNameHandlesAllExcluded() {
        // When all names are excluded, it should still return something
        let allExcluded = generator.allCityNames
        let name = generator.generateUniqueName(excluding: allExcluded, existingNames: [])

        XCTAssertFalse(name.isEmpty)
    }

    func testCityNamesAreUnique() {
        let uniqueNames = Set(generator.allCityNames)
        XCTAssertEqual(uniqueNames.count, generator.allCityNames.count)
    }

    func testCityNamesAreNonEmpty() {
        for name in generator.allCityNames {
            XCTAssertFalse(name.isEmpty)
            XCTAssertFalse(name.contains(" "))  // No spaces
        }
    }
}
