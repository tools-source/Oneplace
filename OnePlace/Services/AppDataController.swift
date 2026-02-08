import Foundation
import SwiftData

@MainActor
final class AppDataController: ObservableObject {
    let container: ModelContainer

    init() {
        let schema = AppSchema.schema
        container = Self.makeLocalContainer(schema: schema)
    }

    private static func makeLocalContainer(schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logContainerError(error, configuration: configuration)
            return makeInMemoryContainer(schema: schema)
        }
    }

    private static func logContainerError(_ error: Error, configuration: ModelConfiguration) {
        print("Failed to create ModelContainer with configuration: \(configuration)")
        dump(error)
        let nsError = error as NSError
        print("NSError domain: \(nsError.domain) code: \(nsError.code)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            print("Underlying error:")
            dump(underlying)
        }
        if let detailedErrors = nsError.userInfo["NSDetailedErrors"] as? [NSError], !detailedErrors.isEmpty {
            print("Detailed errors:")
            detailedErrors.forEach { dump($0) }
        }
        if !nsError.userInfo.isEmpty {
            print("User info:")
            dump(nsError.userInfo)
        }
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let inMemoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        if let inMemoryContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfiguration]) {
            return inMemoryContainer
        }

        print("Unable to create in-memory ModelContainer with schema. Falling back to sample data container.")
        return SampleData.makeFallbackContainer()
    }
}
