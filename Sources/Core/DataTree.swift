import Foundation

/// One node in a collapsible document tree — the shared shape every structured format
/// (JSON, YAML, XML) is projected onto, so the outline view doesn't need per-format
/// knowledge. Pure Foundation, no SwiftUI, same split as every other `Sources/Core/*` file:
/// colors are referred to only as `SyntaxTokenRole` (reused from `SyntaxHighlighter`), and
/// the view maps those to actual themed colors.
///
/// A reference type, not a struct, and specifically an `NSObject`: the view layer renders
/// this through `NSOutlineView`, which keeps track of which items are expanded by *object
/// identity*. A struct would be boxed into a fresh object each time it crossed into AppKit,
/// so no item would ever look like the one that was expanded a moment ago. Inheriting
/// `NSObject` makes identity-based `isEqual:`/`hash` explicit rather than incidental.
/// The tree is built once per document and never mutated, so sharing references is safe.
final class TreeNode: NSObject, Identifiable {
    /// A structural path ("$.users[0].name") — stable across rebuilds of the same document,
    /// which is what lets the view re-expand the same nodes after the content changes.
    let id: String
    /// Property name, array index, or XML element/attribute name. `nil` only for the root.
    let key: String?
    /// Rendered scalar value for a leaf; `nil` for pure containers.
    let valueText: String?
    let valueRole: SyntaxTokenRole?
    /// Child count summary shown next to a container, e.g. "{3}" or "[5]".
    let badge: String?
    let children: [TreeNode]
    /// Total nodes in this subtree, including itself. Accumulated during construction (each
    /// node just sums its children's already-known counts) so callers never have to walk the
    /// tree to size it.
    let nodeCount: Int

    init(
        id: String,
        key: String?,
        valueText: String?,
        valueRole: SyntaxTokenRole?,
        badge: String?,
        children: [TreeNode]
    ) {
        self.id = id
        self.key = key
        self.valueText = valueText
        self.valueRole = valueRole
        self.badge = badge
        self.children = children
        self.nodeCount = children.reduce(1) { $0 + $1.nodeCount }
        super.init()
    }

    var isLeaf: Bool { children.isEmpty }
}

enum TreeBuildError: LocalizedError {
    case unsupported
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .unsupported: return "This format doesn't have a tree view."
        case .invalid(let message): return message
        }
    }
}

/// Builds a `TreeNode` hierarchy from already-formatted output text. Each format reuses the
/// parser the app already has rather than introducing a second one: JSON via
/// `JSONSerialization`, YAML via the hand-written `YAMLParser`, XML via Foundation's
/// `XMLDocument` (the same one `XMLTool` formats with).
enum DataTree {
    static func build(_ text: String, language: SyntaxLanguage) throws -> TreeNode {
        switch language {
        case .json: return try fromJSON(text)
        case .yaml: return try fromYAML(text)
        case .xml: return try fromXML(text)
        case .none, .html, .css: throw TreeBuildError.unsupported
        }
    }

    // MARK: - JSON

    static func fromJSON(_ text: String) throws -> TreeNode {
        guard let data = text.data(using: .utf8) else {
            throw TreeBuildError.invalid("Input isn't valid UTF-8 text.")
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return node(fromJSON: object, key: nil, path: "$")
    }

    private static func node(fromJSON value: Any, key: String?, path: String) -> TreeNode {
        if let dictionary = value as? [String: Any] {
            // JSONSerialization hands back an unordered dictionary, so sort for a stable
            // display order — the same reason JSONFormatter passes `.sortedKeys`.
            let children = dictionary.keys.sorted().map { childKey in
                node(fromJSON: dictionary[childKey] ?? NSNull(), key: childKey, path: "\(path).\(childKey)")
            }
            return TreeNode(
                id: path, key: key, valueText: nil, valueRole: nil,
                badge: "{\(children.count)}", children: children
            )
        }
        if let array = value as? [Any] {
            let children = array.enumerated().map { index, element in
                node(fromJSON: element, key: "\(index)", path: "\(path)[\(index)]")
            }
            return TreeNode(
                id: path, key: key, valueText: nil, valueRole: nil,
                badge: "[\(children.count)]", children: children
            )
        }
        let scalar = describeJSONScalar(value)
        return TreeNode(
            id: path, key: key, valueText: scalar.text, valueRole: scalar.role,
            badge: nil, children: []
        )
    }

    private static func describeJSONScalar(_ value: Any) -> (text: String, role: SyntaxTokenRole) {
        if value is NSNull { return ("null", .keyword) }
        if let number = value as? NSNumber {
            // JSONSerialization boxes booleans as NSNumber too, and `as? Bool` would happily
            // match a plain 0/1 — comparing the CoreFoundation type ID is the only reliable
            // way to tell an actual JSON `true`/`false` from the number 1.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return (number.boolValue ? "true" : "false", .keyword)
            }
            return (number.stringValue, .number)
        }
        if let string = value as? String { return ("\"\(string)\"", .string) }
        return (String(describing: value), .string)
    }

    // MARK: - YAML

    static func fromYAML(_ text: String) throws -> TreeNode {
        let value = try YAMLParser.parse(text)
        return node(fromYAML: value, key: nil, path: "$")
    }

    private static func node(fromYAML value: YAMLValue, key: String?, path: String) -> TreeNode {
        switch value {
        case .object(let pairs):
            // Unlike JSON above, `YAMLValue.object` already preserves source order — nothing
            // to sort, and sorting here would actually lose information.
            let children = pairs.map { pair in
                node(fromYAML: pair.1, key: pair.0, path: "\(path).\(pair.0)")
            }
            return TreeNode(
                id: path, key: key, valueText: nil, valueRole: nil,
                badge: "{\(children.count)}", children: children
            )
        case .array(let items):
            let children = items.enumerated().map { index, item in
                node(fromYAML: item, key: "\(index)", path: "\(path)[\(index)]")
            }
            return TreeNode(
                id: path, key: key, valueText: nil, valueRole: nil,
                badge: "[\(children.count)]", children: children
            )
        case .string(let s):
            return leaf(path: path, key: key, text: "\"\(s)\"", role: .string)
        case .int(let i):
            return leaf(path: path, key: key, text: String(i), role: .number)
        case .double(let d):
            return leaf(path: path, key: key, text: String(d), role: .number)
        case .bool(let b):
            return leaf(path: path, key: key, text: b ? "true" : "false", role: .keyword)
        case .null:
            return leaf(path: path, key: key, text: "null", role: .keyword)
        }
    }

    private static func leaf(path: String, key: String?, text: String, role: SyntaxTokenRole) -> TreeNode {
        TreeNode(id: path, key: key, valueText: text, valueRole: role, badge: nil, children: [])
    }

    // MARK: - XML

    static func fromXML(_ text: String) throws -> TreeNode {
        let document: XMLDocument
        do {
            document = try XMLDocument(xmlString: text, options: [])
        } catch {
            throw TreeBuildError.invalid("Invalid XML: \(error.localizedDescription)")
        }
        guard let root = document.rootElement() else {
            throw TreeBuildError.invalid("XML document has no root element.")
        }
        return node(fromXML: root, path: "$")
    }

    private static func node(fromXML element: XMLElement, path: String) -> TreeNode {
        let name = element.name ?? "element"
        let nodePath = "\(path)/\(name)"
        var children: [TreeNode] = []

        // Attributes are shown as `@name` pseudo-children — the conventional way XML tree
        // viewers surface them without inventing a second column.
        for attribute in element.attributes ?? [] {
            let attributeName = attribute.name ?? "attribute"
            children.append(TreeNode(
                id: "\(nodePath)/@\(attributeName)",
                key: "@\(attributeName)",
                valueText: "\"\(attribute.stringValue ?? "")\"",
                valueRole: .string,
                badge: nil,
                children: []
            ))
        }

        let childElements = (element.children ?? []).compactMap { $0 as? XMLElement }
        for (index, child) in childElements.enumerated() {
            // The index is part of the path so repeated sibling tags (`<item>` x5) still get
            // unique, stable ids rather than colliding on name alone.
            children.append(node(fromXML: child, path: "\(nodePath)[\(index)]"))
        }

        // A childless element's text content becomes this node's own value, so
        // `<name>Ada</name>` reads as one line instead of a container wrapping a text node.
        if childElements.isEmpty {
            let content = element.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !content.isEmpty {
                return TreeNode(
                    id: nodePath, key: name, valueText: content, valueRole: .string,
                    badge: nil, children: children
                )
            }
        }
        return TreeNode(
            id: nodePath, key: name, valueText: nil, valueRole: nil,
            badge: children.isEmpty ? nil : "{\(children.count)}", children: children
        )
    }
}
