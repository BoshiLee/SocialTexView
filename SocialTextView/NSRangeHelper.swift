//
//  NSRangeHelper.swift
//  SocialLabel
//
//  Created by Boshi Li on 2018/11/14.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import CoreText
import Foundation

extension String {
    
    func nsRange(from range: Range<String.Index>) -> NSRange {
        return NSRange(range, in: self)
    }
    
    func ranges(of searchString: String, options mask: NSString.CompareOptions = [], locale: Locale? = nil) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        while let range = range(of: searchString, options: mask, range: (ranges.last?.upperBound ?? startIndex)..<endIndex, locale: locale) {
            ranges.append(range)
        }
        return ranges
    }
    
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex) else { return nil }
        guard let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex) else { return nil }
        guard let from = String.Index(from16, within: self) else { return nil }
        guard let to = String.Index(to16, within: self) else { return nil }
        return from ..< to
    }
    
    func nsRanges(of searchString: String, options mask: NSString.CompareOptions = [], locale: Locale? = nil) -> [NSRange] {
        let ranges = self.ranges(of: searchString, options: mask, locale: locale)
        return ranges.map { nsRange(from: $0) }
    }
    
    func subString(with nsRange: NSRange) -> String? {
        guard let range = self.range(from: nsRange) else { return nil }
        return String(self[range])
    }
    
    mutating func removeSubrange(_ range: NSRange) {
        let nsSelf = self as NSString
        if range.location + range.length <= nsSelf.length {
            self.replaceSubrange(range, withReplacementText: "")
        } else {
            self.removeSubrangeContainsEmoji(range)
        }
    }
    
    mutating func removeSubrangeContainsEmoji(_ range: NSRange) {
        let newRange = NSRange(location: range.location - range.length + 1, length: range.length)
        let nsSelf = self as NSString
        self = nsSelf.replacingCharacters(in: newRange, with: "") as String
    }
    
    mutating func replaceSubrange(_ subrange: NSRange, withReplacementText text: String) {
        guard self.range(from: subrange) != nil else { return }
        self = (self as NSString).replacingCharacters(in: subrange, with: text)
    }
}

extension String {
    
    func removeHTMLTags() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
    
    func int(of stringIndex: String.Index) -> Int {
        return self.distance(from: self.startIndex, to: stringIndex)
    }
    
    func rangeOfEndIndex(from stratIndex: String.Index) -> NSRange {
        return NSRange(location: self.int(of: startIndex), length: self.int(of: self.endIndex))
    }
    
    func isLastCharcter(is string: Character) -> Bool {
        guard let lastString = self.last, lastString == string else { return false }
        return true
    }
    
}
