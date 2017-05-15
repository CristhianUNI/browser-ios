//
// SQLite.swift
// https://github.com/stephencelis/SQLite.swift
// Copyright © 2014-2015 Stephen Celis.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

extension Module {

    public static func FTS4(_ column: Expressible, _ more: Expressible...) -> Module {
        return FTS4([column] + more)
    }

    public static func FTS4(_ columns: [Expressible] = [], tokenize tokenizer: Tokenizer? = nil) -> Module {
        var columns: [Expressible] = columns
        if let tokenizer = tokenizer {
            columns.append("=".join([Expression<Void>(literal: "tokenize"), Expression<Void>(literal: tokenizer.description)]))
        }
        return Module(name: "fts4", arguments: columns)
    }

}

extension VirtualTable {

    /// Builds an expression appended with a `MATCH` query against the given
    /// pattern.
    ///
    ///     let emails = VirtualTable("emails")
    ///
    ///     emails.filter(emails.match("Hello"))
    ///     // SELECT * FROM "emails" WHERE "emails" MATCH 'Hello'
    ///
    /// - Parameter pattern: A pattern to match.
    ///
    /// - Returns: An expression appended with a `MATCH` query against the given
    ///   pattern.
    public func match(_ pattern: String) -> Expression<Bool> {
        return "MATCH".infix(tableName(), pattern)
    }

    public func match(_ pattern: Expression<String>) -> Expression<Bool> {
        return "MATCH".infix(tableName(), pattern)
    }

    public func match(_ pattern: Expression<String?>) -> Expression<Bool?> {
        return "MATCH".infix(tableName(), pattern)
    }

    /// Builds a copy of the query with a `WHERE … MATCH` clause.
    ///
    ///     let emails = VirtualTable("emails")
    ///
    ///     emails.match("Hello")
    ///     // SELECT * FROM "emails" WHERE "emails" MATCH 'Hello'
    ///
    /// - Parameter pattern: A pattern to match.
    ///
    /// - Returns: A query with the given `WHERE … MATCH` clause applied.
    public func match(_ pattern: String) -> QueryType {
        return filter(match(pattern))
    }

    public func match(_ pattern: Expression<String>) -> QueryType {
        return filter(match(pattern))
    }

    public func match(_ pattern: Expression<String?>) -> QueryType {
        return filter(match(pattern))
    }

}

public struct Tokenizer {

    public static let Simple = Tokenizer("simple")

    public static let Porter = Tokenizer("porter")

    public static func Unicode61(removeDiacritics: Bool? = nil, tokenchars: Set<Character> = [], separators: Set<Character> = []) -> Tokenizer {
        var arguments = [String]()

        if let removeDiacritics = removeDiacritics {
            arguments.append("removeDiacritics=\(removeDiacritics ? 1 : 0)".quote())
        }

        if !tokenchars.isEmpty {
            let joined = tokenchars.map { String($0) }.joined(separator: "")
            arguments.append("tokenchars=\(joined)".quote())
        }

        if !separators.isEmpty {
            let joined = separators.map { String($0) }.joined(separator: "")
            arguments.append("separators=\(joined)".quote())
        }

        return Tokenizer("unicode61", arguments)
    }

    public static func Custom(_ name: String) -> Tokenizer {
        return Tokenizer(Tokenizer.moduleName.quote(), [name.quote()])
    }

    public let name: String

    public let arguments: [String]

    fileprivate init(_ name: String, _ arguments: [String] = []) {
        self.name = name
        self.arguments = arguments
    }

    fileprivate static let moduleName = "SQLite.swift"

}

extension Tokenizer : CustomStringConvertible {

    public var description: String {
        return ([name] + arguments).joined(separator: " ")
    }

}

extension Connection {

    public func registerTokenizer(_ submoduleName: String, next: @escaping (String) -> (String, Range<String.Index>)?) throws {
        try check(_SQLiteRegisterTokenizer(handle, Tokenizer.moduleName, submoduleName) { input, offset, length in
            let string = String(cString: input)
            if let (token, range) = next(string) {
                let view = string.utf8
                offset.pointee += string.substring(to: range.lowerBound).utf8.count
                length.pointee = Int32(<#T##String.UTF8View corresponding to your index##String.UTF8View#>.distance(from: range.lowerBound.samePosition(in: view), to: range.upperBound.samePosition(in: view)))
                return token
            }
            return nil
        })
    }

}
