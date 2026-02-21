import Foundation

enum ServerConfig {
    #if DEBUG
    static let baseURL = "https://dev.studyreef.com"
    #else
    static let baseURL = "https://api.studyreef.com"
    #endif
}
