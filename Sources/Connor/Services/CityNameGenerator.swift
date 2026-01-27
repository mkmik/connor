import Foundation

/// Protocol for generating unique workspace names
protocol CityNameGeneratorProtocol {
    func generateUniqueName(excluding recentlyUsed: [String], existingNames: [String]) -> String
    var allCityNames: [String] { get }
}

/// Generates memorable workspace names using world city names
final class CityNameGenerator: CityNameGeneratorProtocol {
    /// Curated list of world cities - memorable, diverse, easy to type
    let allCityNames: [String] = [
        // Africa
        "Casablanca", "Cairo", "Nairobi", "Lagos", "Marrakech", "Tunis", "Accra", "Addis",
        // Asia
        "Tokyo", "Seoul", "Bangkok", "Singapore", "Mumbai", "Delhi", "Shanghai", "Beijing",
        "Hanoi", "Manila", "Jakarta", "Taipei", "Osaka", "Kyoto", "Busan", "HongKong",
        "Bangalore", "Chennai", "Kolkata", "Karachi", "Dhaka", "Yangon", "Phnom",
        // Europe
        "London", "Paris", "Berlin", "Rome", "Madrid", "Barcelona", "Amsterdam", "Vienna",
        "Prague", "Budapest", "Warsaw", "Dublin", "Edinburgh", "Lisbon", "Athens",
        "Stockholm", "Oslo", "Copenhagen", "Helsinki", "Brussels", "Zurich", "Geneva",
        "Munich", "Milan", "Venice", "Florence", "Lyon", "Marseille", "Porto", "Seville",
        "Krakow", "Split", "Dubrovnik", "Reykjavik", "Tallinn", "Riga", "Vilnius",
        // North America
        "Austin", "Denver", "Seattle", "Portland", "Boston", "Chicago", "Phoenix",
        "Montreal", "Vancouver", "Toronto", "Miami", "Nashville", "Atlanta", "Dallas",
        "SanDiego", "Oakland", "Detroit", "Memphis", "NewOrleans", "SaltLake",
        // South America
        "Lima", "Santiago", "Bogota", "Quito", "Montevideo", "Caracas", "Medellin",
        "BuenosAires", "RioDeJaneiro", "SaoPaulo", "Cusco", "Cartagena",
        // Oceania
        "Sydney", "Melbourne", "Auckland", "Brisbane", "Perth", "Wellington", "Adelaide",
        // Middle East
        "Dubai", "Istanbul", "TelAviv", "Beirut", "Amman", "Doha", "Riyadh", "Muscat"
    ]

    func generateUniqueName(excluding recentlyUsed: [String], existingNames: [String]) -> String {
        let excluded = Set(recentlyUsed + existingNames)
        let available = allCityNames.filter { !excluded.contains($0) }

        // If all names used, pick from least recently used
        if available.isEmpty {
            // Pick one that's not in existingNames at least
            let notCurrent = allCityNames.filter { !existingNames.contains($0) }
            return notCurrent.randomElement() ?? "Workspace\(Int.random(in: 1000...9999))"
        }

        return available.randomElement() ?? "Workspace"
    }
}
