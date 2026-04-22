import Foundation

struct BookSummary: Codable, Identifiable {
    let id: Int
    let title: String
    let author: String
    let cover_url: String?
    let min_price: Int
    let store_count: Int
    let category: String?
}

struct BookCategory: Codable, Identifiable {
    let category: String
    let count: Int
    var id: String { category }

    static let allLabel = "sve"

    static let labels: [String: String] = [
        "romani":      "Romani",
        "deca":        "Deca",
        "istorija":    "Istorija",
        "nauka":       "Nauka",
        "psihologija": "Psihologija",
        "biznis":      "Biznis",
        "filozofija":  "Filozofija",
        "religija":    "Religija",
        "umetnost":    "Umetnost",
        "kuvari":      "Kuvari",
        "biografije":  "Biografije",
        "ostalo":      "Ostalo",
    ]

    var label: String { BookCategory.labels[category] ?? category }
}

struct Listing: Codable, Identifiable {
    var id: String { store }
    let store: String
    let store_label: String
    let store_url: String
    let price: Int
    let in_stock: Int
}

struct BookDetail: Codable, Identifiable {
    let id: Int
    let title: String
    let author: String
    let description: String?
    let cover_url: String?
    let isbn: String?
    let listings: [Listing]
}

struct WishlistBook: Codable, Identifiable {
    let id: Int           // book_id
    let title: String
    let author: String
    let cover_url: String?
    let min_price: Int?
    let store_count: Int?
    let added_at: String?
}

struct BooksResponse: Codable {
    let books: [BookSummary]
    let total: Int
    let page: Int
    let limit: Int
}
