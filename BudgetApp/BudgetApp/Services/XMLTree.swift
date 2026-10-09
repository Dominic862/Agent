import Foundation

/// Minimaler XML-Baum für die Teile einer .xlsx-Datei. Namespace-Präfixe werden entfernt.
final class XNode {
    let name: String
    let attributes: [String: String]
    var children: [XNode] = []
    var text = ""

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    func children(_ name: String) -> [XNode] { children.filter { $0.name == name } }
    func child(_ name: String) -> XNode? { children.first { $0.name == name } }

    func descendants(_ name: String) -> [XNode] {
        var result: [XNode] = []
        for c in children {
            if c.name == name { result.append(c) }
            result.append(contentsOf: c.descendants(name))
        }
        return result
    }

    static func parse(_ data: Data) throws -> XNode {
        let builder = XTreeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        guard parser.parse(), let root = builder.root else {
            throw parser.parserError ?? XLSXError.invalidFile
        }
        return root
    }
}

private final class XTreeBuilder: NSObject, XMLParserDelegate {
    private var stack: [XNode] = []
    var root: XNode?

    private func local(_ name: String) -> String {
        guard let i = name.lastIndex(of: ":") else { return name }
        return String(name[name.index(after: i)...])
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        var attrs: [String: String] = [:]
        for (key, value) in attributeDict where !key.hasPrefix("xmlns") {
            attrs[local(key)] = value
        }
        let node = XNode(name: local(elementName), attributes: attrs)
        if let parent = stack.last {
            parent.children.append(node)
        } else {
            root = node
        }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        _ = stack.popLast()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }
}
