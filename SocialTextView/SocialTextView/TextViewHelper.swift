//
//  TextViewHelper.swift
//  SocialTextField
//
//  Created by Boshi Li on 2018/11/21.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import UIKit

extension SocialTextView {
    
    var startPosition: UITextPosition {
        return self.beginningOfDocument
    }
    
    var endPosition: UITextPosition {
        return self.endOfDocument
    }
    
    func getCursorPosition() -> Int {
        if let selectedRange = self.selectedTextRange {
            return self.offset(from: self.startPosition, to: selectedRange.start)
        } else {
            return 0
        }
    }
    
    func setCusor(to arbitraryValue: Int) {
        // only if there is a currently selected range
        if let selectedRange = self.selectedTextRange {
            
            // and only if the new position is valid
            if let newPosition = self.position(from: selectedRange.start, offset: arbitraryValue) {
                // set the new position
                self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
            }
        }
    }
    
    func getCurrentTypingLocation() -> Int {
        return self.selectedRange.location - 1 < 0 ? 0 : self.selectedRange.location - 1
    }
    
    func getCurrentTypingCharacter() -> String? {
        let nsText = text as NSString
        let newLocation = self.selectedRange.location - 1 < 0 ? 0 : self.selectedRange.location - 1
        let newRange = NSRange(location: newLocation, length: 1)
        guard nsText.length >= newRange.length else { return nil }
        return nsText.substring(with: newRange)
    }
    
    func isCurrentTyping(is string: String) -> Bool {
        return self.getCurrentTypingCharacter() == string
    }
    
    func isTypingChineseAlpahbet() -> Bool {
        ///取得當前TextField選取的文字區域
        if let positionRange = self.markedTextRange {
            if let _ = self.position(from: positionRange.start, offset: 0) {
                return true
            } else { return false }
        } else {
            return false
        }
    }
    
    var markedTypingRange: NSRange? {
        let beginning = self.beginningOfDocument
        if let selectedRange = self.markedTextRange {
            ///取得選取文字區域的開始點
            let selectionStart = selectedRange.start
            ///取得選取文字區域的結束點
            let selectionEnd = selectedRange.end
            ///取得TextField文案的開始點到選擇文字區域的開始點的字數
            let startPosition = self.offset(from: beginning, to: selectionStart)
            ///取得TextField文案的開始點到選擇文字區域的結束點的字數
            let endPosition = self.offset(from: beginning, to: selectionEnd)
            ///印出結果
            print("start = \(startPosition), end = \(endPosition)")
            return NSRange(location: startPosition, length: endPosition - startPosition)
        } else {
            return nil
        }
    }
    
    var postingText: String {
        var prsentingText = self.text!
        var uiMentionRanges = self.uiMentionRanges
        while !uiMentionRanges.isEmpty {
            let content = self.popUpFirstMention(form: uiMentionRanges, presentingText: prsentingText)
            prsentingText = content.prsentingText
            uiMentionRanges = content.ranges
        }
        return prsentingText
    }
    
    // MARK: - Origin Text Handlers
    private func tagUserString(formRange range: SCTVMentionRange) -> String {
        return "<tagUser>@\(range.mentionUser.account)</tagUser>"
    }
    
    private func popUpFirstMention(form ranges: [SCTVMentionRange], presentingText: String) -> (prsentingText: String, ranges: [SCTVMentionRange]) {
        var uiMentionRanges = ranges
        var prsentingText = presentingText
        guard let firstMenstion = uiMentionRanges.first else { return (presentingText, ranges) }
        let firstTagUserString = self.tagUserString(formRange: firstMenstion)
        uiMentionRanges.removeFirst()
        
        for (i, uiMentionRange) in uiMentionRanges.enumerated() {
            let newRangelocation = uiMentionRange.nickNameRange.location - firstMenstion.nickNameRange.length + firstTagUserString.nsString.length
            uiMentionRanges[i].nickNameRange.location = newRangelocation
        }
        
        prsentingText.replaceSubrange(firstMenstion.nickNameRange, withReplacementText: self.tagUserString(formRange: firstMenstion))
        return (prsentingText, uiMentionRanges)
    }
    
    func setText(fromOriginText originText: inout String, mentionDict: MentionDict) -> [SCTVMentionRange] {
        let elements = ElementBuilder.relpaceMentions(form: &originText, with: mentionDict)
        return elements.compactMap {
            guard let mentionUser = mentionDict[$0.content], mentionUser.shouldActive else { return nil }
            return SCTVMentionRange(nickNameRange: $0.range, mentionUser: mentionUser)
        }
    }
}

