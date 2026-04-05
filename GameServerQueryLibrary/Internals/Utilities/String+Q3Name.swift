//
//  String+Q3Name.swift
//  Q3ServerBrowser
//
//  Created by Andrea Giavatto on 27/07/2017.
//
//

import Foundation

public extension String {

    // Compiled once at class-load time and reused for every call.
    // NSRegularExpression is thread-safe for concurrent matching once compiled,
    // so a shared static is correct here.
    private static let q3SimpleColorRegex = try! NSRegularExpression(
        pattern: "\\^+[0-9]", options: .caseInsensitive)
    private static let q3BgColorRegex = try! NSRegularExpression(
        pattern: "\\^+[0-9A-Z]{6}", options: .caseInsensitive)
    private static let q3BlinkRegex = try! NSRegularExpression(
        pattern: "\\^+[a-z]", options: .caseInsensitive)

    var q3ColorDecoded: String {
        guard !self.isEmpty else { return self }

        // NSRegularExpression requires the UTF-16 length (NSString.length),
        // not the Swift Character count, for its NSRange parameter.
        var result = self
        var nsResult = result as NSString
        result = String.q3SimpleColorRegex.stringByReplacingMatches(
            in: result, options: [], range: NSRange(location: 0, length: nsResult.length),
            withTemplate: "")  // strips ^0 … ^9 colour codes

        nsResult = result as NSString
        result = String.q3BgColorRegex.stringByReplacingMatches(
            in: result, options: [], range: NSRange(location: 0, length: nsResult.length),
            withTemplate: "")  // strips ^RRGGBB background colour codes

        nsResult = result as NSString
        result = String.q3BlinkRegex.stringByReplacingMatches(
            in: result, options: [], range: NSRange(location: 0, length: nsResult.length),
            withTemplate: "")  // strips ^a … ^z style codes (blink, bold, etc.)

        return result
    }
}
