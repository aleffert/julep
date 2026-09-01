import Foundation
#if canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
#elseif canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
#endif

/// How each role is drawn.
///
/// The journal is plain text and should still read as plain text: styling
/// distinguishes structure by weight and colour, and never by anything that would make the
/// underlying characters look like something other than what they are.
/// Not `Sendable`: `NSFont`/`UIFont` are not, and a theme is only ever touched on the main
/// thread alongside the text view it styles.
public struct Theme {
    public var font: PlatformFont
    public var textColor: PlatformColor
    public var headerColor: PlatformColor
    public var labelColor: PlatformColor
    public var deltaColor: PlatformColor
    public var markerColor: PlatformColor
    public var tagColor: PlatformColor
    public var annotationColor: PlatformColor
    public var unrecognizedColor: PlatformColor
    /// A phone number, email or link inside an item. The system link colour, because that is
    /// what it means.
    public var detectedColor: PlatformColor
    /// Extra space between lines. A journal is read as a list of short lines rather than as
    /// prose, and default leading packs them tighter than that wants -- particularly on a
    /// phone, where the lines are also the touch targets.
    public var lineSpacing: CGFloat = 0

    public static func standard(size: CGFloat, lineSpacing: CGFloat = 0) -> Theme {
        var theme = base(size: size)
        theme.lineSpacing = lineSpacing
        return theme
    }

    private static func base(size: CGFloat) -> Theme {
        #if canImport(AppKit)
        return Theme(
            font: .systemFont(ofSize: size),
            textColor: .labelColor,
            headerColor: .labelColor,
            labelColor: .secondaryLabelColor,
            deltaColor: .tertiaryLabelColor,
            // Secondary, not tertiary: the marker is de-emphasised but still meaningful --
            // it is what makes a line an item -- and tertiary all but vanishes on black.
            markerColor: .secondaryLabelColor,
            tagColor: .systemTeal,
            annotationColor: .systemPurple,
            unrecognizedColor: .systemOrange,
            detectedColor: .linkColor
        )
        #else
        return Theme(
            font: .systemFont(ofSize: size),
            textColor: .label,
            headerColor: .label,
            labelColor: .secondaryLabel,
            deltaColor: .tertiaryLabel,
            // See the AppKit branch: tertiary all but vanishes on black.
            markerColor: .secondaryLabel,
            tagColor: .systemTeal,
            annotationColor: .systemPurple,
            unrecognizedColor: .systemOrange,
            detectedColor: .link
        )
        #endif
    }

    public var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        return [.font: font, .foregroundColor: textColor, .paragraphStyle: paragraph]
    }

    public func attributes(for role: HighlightRole) -> [NSAttributedString.Key: Any] {
        switch role {
        case .dayHeader:
            [.foregroundColor: headerColor,
             .font: PlatformFont.systemFont(ofSize: font.pointSize, weight: .bold)]
        case .sectionLabel:
            [.foregroundColor: labelColor,
             .font: PlatformFont.systemFont(ofSize: font.pointSize, weight: .semibold)]
        case .delta:
            [.foregroundColor: deltaColor]
        case .itemMarker:
            [.foregroundColor: markerColor]
        case .tag:
            [.foregroundColor: tagColor]
        case .annotation:
            [.foregroundColor: annotationColor]
        case .unrecognized:
            // Underlined rather than recoloured alone: an unreadable line is worth noticing
            // even at a glance, because it means the file and the app disagree.
            [.foregroundColor: unrecognizedColor,
             .underlineStyle: NSUnderlineStyle.patternDot.union(.single).rawValue]
        case .detectedData:
            // Underlined as well as coloured: it is the convention for something you can
            // act on, and colour alone leaves the affordance to be discovered by accident.
            // A plain single rule, so it does not read as the dotted one on a line the
            // grammar could not make sense of.
            [.foregroundColor: detectedColor,
             .underlineStyle: NSUnderlineStyle.single.rawValue,
             .underlineColor: detectedColor]
        }
    }
}
