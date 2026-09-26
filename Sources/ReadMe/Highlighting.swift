import Splash
import SwiftUI

enum Highlighter {
    static func attributed(_ text: String, language: String?, dark: Bool) -> AttributedString {
        let font = Splash.Font(size: 13)
        let theme = dark ? Theme.midnight(withFont: font) : Theme.sunset(withFont: font)
        let format = AttributedStringOutputFormat(theme: theme)
        let highlighter = SyntaxHighlighter(format: format, grammar: grammar(for: language))
        let output = highlighter.highlight(text)
        return AttributedString(output)
    }

    private static func grammar(for language: String?) -> Grammar {
        switch language {
        case "swift": return SwiftGrammar()
        case "javascript", "typescript":
            return KeywordGrammar(keywords: [
                "async", "await", "break", "case", "catch", "class", "const", "continue",
                "debugger", "default", "delete", "do", "else", "export", "extends", "false",
                "finally", "for", "function", "if", "import", "in", "instanceof", "let",
                "new", "null", "return", "static", "super", "switch", "this", "throw",
                "true", "try", "typeof", "var", "void", "while", "with", "yield",
            ], lineComment: "//", blockComment: ("/*", "*/"))
        case "python":
            return KeywordGrammar(keywords: [
                "and", "as", "assert", "async", "await", "break", "class", "continue",
                "def", "del", "elif", "else", "except", "false", "finally", "for",
                "from", "global", "if", "import", "in", "is", "lambda", "none", "nonlocal",
                "not", "or", "pass", "raise", "return", "true", "try", "while", "with", "yield",
            ], lineComment: "#", blockComment: ("\"\"\"", "\"\"\""))
        case "go":
            return KeywordGrammar(keywords: [
                "break", "case", "chan", "const", "continue", "default", "defer", "else",
                "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
                "map", "package", "range", "return", "select", "struct", "switch", "type", "var",
            ], lineComment: "//", blockComment: ("/*", "*/"))
        case "rust":
            return KeywordGrammar(keywords: [
                "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else",
                "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop",
                "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self",
                "static", "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while",
            ], lineComment: "//", blockComment: ("/*", "*/"))
        case "json":
            return KeywordGrammar(keywords: ["true", "false", "null"], lineComment: nil, blockComment: nil)
        case "yaml":
            return KeywordGrammar(keywords: ["true", "false", "null", "yes", "no"], lineComment: "#", blockComment: nil)
        case "toml":
            return KeywordGrammar(keywords: ["true", "false"], lineComment: "#", blockComment: nil)
        case "css":
            return KeywordGrammar(keywords: [
                "align-items", "block", "color", "display", "flex", "font", "grid", "height",
                "margin", "padding", "position", "width",
            ], lineComment: nil, blockComment: ("/*", "*/"))
        case "html":
            return KeywordGrammar(keywords: [
                "div", "span", "html", "head", "body", "script", "style", "link", "meta",
                "title", "a", "p", "ul", "li", "h1", "h2", "h3",
            ], lineComment: nil, blockComment: ("<!--", "-->"))
        case "shell":
            return KeywordGrammar(keywords: [
                "if", "then", "else", "fi", "for", "do", "done", "case", "esac", "while",
                "function", "return", "in",
            ], lineComment: "#", blockComment: nil)
        default:
            return KeywordGrammar(keywords: [], lineComment: nil, blockComment: nil)
        }
    }
}

struct KeywordGrammar: Grammar {
    let keywords: Set<String>
    let lineComment: String?
    let blockComment: (String, String)?

    var delimiters: CharacterSet {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("'")
        set.remove("#")
        return set
    }

    var syntaxRules: [SyntaxRule] {
        var rules: [SyntaxRule] = [
            KeywordRule(keywords: keywords),
            StringRule(),
            NumberRule(),
        ]
        if let lineComment {
            rules.append(LineCommentRule(prefix: lineComment))
        }
        if let blockComment {
            rules.append(BlockCommentRule(open: blockComment.0, close: blockComment.1))
        }
        return rules
    }
}

struct KeywordRule: SyntaxRule {
    let keywords: Set<String>
    var tokenType: TokenType { .keyword }
    func matches(_ segment: Segment) -> Bool {
        keywords.contains(segment.tokens.current)
    }
}

struct StringRule: SyntaxRule {
    var tokenType: TokenType { .string }
    func matches(_ segment: Segment) -> Bool {
        segment.tokens.current.hasPrefix("\"") || segment.tokens.current.hasPrefix("'")
    }
}

struct NumberRule: SyntaxRule {
    var tokenType: TokenType { .number }
    func matches(_ segment: Segment) -> Bool {
        segment.tokens.current.contains(where: \.isNumber)
            && segment.tokens.current.allSatisfy { $0.isNumber || $0 == "." }
    }
}

struct LineCommentRule: SyntaxRule {
    let prefix: String
    var tokenType: TokenType { .comment }
    func matches(_ segment: Segment) -> Bool {
        segment.tokens.current.hasPrefix(prefix)
    }
}

struct BlockCommentRule: SyntaxRule {
    let open: String
    let close: String
    var tokenType: TokenType { .comment }
    func matches(_ segment: Segment) -> Bool {
        segment.tokens.current.contains(open) || segment.tokens.current.contains(close)
    }
}
