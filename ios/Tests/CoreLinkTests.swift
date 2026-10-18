import Foundation
import MonehCore
import Testing

struct CoreLinkTests {
    @Test func coreFrameworkIsLinked() {
        // Every Kotlin/Native framework exports KotlinBase; resolving it proves MonehCore links.
        #expect(NSStringFromClass(KotlinBase.self).isEmpty == false)
    }
}
