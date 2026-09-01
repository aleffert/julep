/// A UTF-16 offset range into a line's raw text.
///
/// UTF-16 because every consumer of a span is a text view: highlighting attaches
/// attributes through `NSTextContentStorage`, which indexes in UTF-16.
public struct Span: Equatable, Sendable {
    public var location: Int
    public var length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}
