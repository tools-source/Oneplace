import Foundation

struct AppUser: Codable, Equatable {
    let uid: String
    let email: String?
    let fullName: String?
    let provider: String
}
