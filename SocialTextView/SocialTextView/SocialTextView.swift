//
//  SocialTextView.swift
//  SocialTextField
//
//  Created by Boshi Li on 2018/11/20.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import UIKit

enum TypingPosisition {
    case leadingMentions
    case inTheMention(mentionIndex: Int)
    case betweenMention(firstIndex: Int, secondIndex: Int, offset: Int)
    case trallingMentions(lastMentionIndex: Int, offset: Int)
}

class SocialTextView: UITextView {
    
    // MARK: - override UILabel properties
    
    override open var textAlignment: NSTextAlignment {
        didSet { updateTextAttributed(parseText: false)}
    }
    
    // MARK: - Inspectable Properties
    @IBInspectable open var regularFont: UIFont = UIFont.systemFont(ofSize: 17.0) {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var regularColor: UIColor = .black  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var mentionFont: UIFont?  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var mentionColor: UIColor = .blue  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var mentionSelectedColor: UIColor?  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var mentionUnderLineStyle: NSUnderlineStyle = []  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var hashtagFont: UIFont?  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var hashtagColor: UIColor = .blue  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var hashtagSelectedColor: UIColor?  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var hashtagUnderLineStyle: NSUnderlineStyle = [] {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var URLColor: UIColor = .blue  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var URLSelectedColor: UIColor?  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var URLFont: UIFont?  {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    @IBInspectable open var URLUnderLineStyle: NSUnderlineStyle = [] {
        didSet { updateTextAttributed(parseText: false) }
    }
    
    // MARK: - Private Properties don't open it
    private lazy var cachedSocialElements: [SocialElement] = [SocialElement]()
    private lazy var mentionDict: MentionDict = MentionDict()
    private var selectedElement: SocialElement?
    
    // MARK: - Popover related properties
    private var isPopoverPresenting: Bool = false
    private var lastMentionRange: NSRange?
    private var mentionPopoverWindow: MentionWindow?
    fileprivate var _customizing: Bool = true
    fileprivate var cacheMentionRanges: [NSRange] {
        return self.cachedSocialElements.filter{ $0.type == .mention }.map{ $0.range }
    }
    fileprivate lazy var cacheTagUserRanges = [NSRange]()
    fileprivate lazy var isDelecting = false
    fileprivate lazy var isInTextView = false
    // MARK: - Public properties
    open var enableType: [SocialType] = [.mention, .hashtag, .url]
    private lazy var originText: String = ""
    private lazy var prensentingText: String = ""
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _customizing = false
        self.keyboardType = .twitter
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        self.delegate = self
        updateTextAttributed()
    }
    
}

extension SocialTextView: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let char = text.cString(using: String.Encoding.utf8)!
        let isBackSpace = strcmp(char, "\\b")
        guard !self.cacheMentionRanges.isEmpty, !self.cacheTagUserRanges.isEmpty else {
            self.originText.replaceSubrange(range, withReplacementText: text)
            self.popoverHandler(text: text)
            return true
        }
        if (isBackSpace == -92) {
            self.removeOriginText(in: range)
        } else {
            self.updateOriginText(in: range, replacementText: text)
        }
        self.popoverHandler(text: text)
        self.setCusor(to: range.upperBound)
        return true
    }
    
    func updateOriginText(in range: NSRange, replacementText text: String) {
        switch self.cusorPositionType(isInserting: true) {
        case .leadingMentions:
            self.originText.replaceSubrange(range, withReplacementText: text)
        case .inTheMention(let mentionIndex):
            self.originText.replaceSubrange(cacheTagUserRanges[mentionIndex], withReplacementText: text)
            self.cacheTagUserRanges.remove(at: mentionIndex)
        case .betweenMention(_, _, let offset), .trallingMentions(_, let offset):
            self.originText.replaceSubrange(NSRange(location: offset, length: range.length), withReplacementText: text)
        }
        self.cacheTagUserRanges = ElementBuilder.matchesMentions(form: self.originText)
    }
    
    func removeOriginText(in range: NSRange) {
        switch self.cusorPositionType(isInserting: false) {
        case .leadingMentions:
            self.originText.removeSubrange(range)
        case .inTheMention(let mentionIndex):
            self.originText.removeSubrange(self.cacheTagUserRanges[mentionIndex])
            self.cacheTagUserRanges.remove(at: mentionIndex)
        case .betweenMention(_, _, let offset):
            self.originText.removeSubrange(NSRange(location: offset, length: range.length))
        case .trallingMentions(_, let offset):
            self.originText.removeSubrange(NSRange(location: offset, length: range.length))
        }
        self.cacheTagUserRanges = ElementBuilder.matchesMentions(form: self.originText)
    }
    
    
    func textViewDidChange(_ textView: UITextView) {
        textView.isScrollEnabled = false
        var selectedRange = self.selectedRange
        selectedRange.location = self.getCursorPosition()
        guard !self.isTypingChineseAlpahbet() else { return }
        self.updateTextAttributed()
        selectedRange.length = 0
        textView.isScrollEnabled = true
        self.selectedRange = selectedRange
    }
}

// MARK: - Cusor Position Handler
extension SocialTextView {
    func cusorPositionType(isInserting: Bool) -> TypingPosisition {
        for (i, mentionRange) in self.cacheMentionRanges.enumerated() {
            if let markedTypingRange = self.markedTypingRange { // 有在智慧選字模式
                guard let type = self.getCusorPosistionType(withMarkedTypingRange: markedTypingRange, Index: i, mentionRange: mentionRange, isInserting: isInserting) else {
                    continue
                }
                return type
            } else {
                guard let type = self.getCusorPosistionType(withIndex: i, mentionRange: mentionRange, isInserting: isInserting) else {
                    continue
                }
                return type
            }
        }
        // 沒有任何 ragne 時
        return .leadingMentions
    }
    
    private func getCusorPosistionType(withMarkedTypingRange markedTypingRange: NSRange, Index i: Int, mentionRange: NSRange, isInserting: Bool) -> TypingPosisition? {
        let cusorPosistion = markedTypingRange.location
        if (cusorPosistion > mentionRange.lowerBound && cusorPosistion < mentionRange.upperBound) { // 判斷是否在第一個 range 前面
            return .inTheMention(mentionIndex: i)
        } else if i == 0, cusorPosistion <= mentionRange.lowerBound{ // 判斷是否在當下的 range 裡
            return .leadingMentions
        } else if self.cacheMentionRanges.indices.contains(i + 1) {
            if (cusorPosistion >= mentionRange.upperBound && cusorPosistion <= self.cacheMentionRanges[i + 1].lowerBound) {
                let offsetIndex = cusorPosistion - self.cacheMentionRanges[i].upperBound
                var tagUserOffsetIndex = self.cacheTagUserRanges[i].upperBound + offsetIndex
                tagUserOffsetIndex = isInserting ? tagUserOffsetIndex : tagUserOffsetIndex + 1
                return .betweenMention(firstIndex: i, secondIndex: i + 1, offset: tagUserOffsetIndex)
            } else {
                return nil
            }
        } else { // 後面無 range
            let offsetIndex = cusorPosistion - self.cacheMentionRanges[i].upperBound
            let tagUserOffsetIndex = self.cacheTagUserRanges[i].upperBound + offsetIndex
            return .trallingMentions(lastMentionIndex: i, offset: tagUserOffsetIndex)
        }
    }
    
    private func getCusorPosistionType(withIndex i: Int, mentionRange: NSRange, isInserting: Bool) -> TypingPosisition? {
        var cusorPosistion = self.getCursorPosition()
        if isInserting {
            cusorPosistion = self.getCursorPosition()
        } else {
            // 刪除時要退一格
            cusorPosistion = cusorPosistion - 1 >= 0 ? cusorPosistion - 1 : 0
        }
        if (cusorPosistion > mentionRange.lowerBound && cusorPosistion < mentionRange.upperBound) { // 判斷是否在第一個 range 前面
            return .inTheMention(mentionIndex: i)
        } else if  i == 0, cusorPosistion <= mentionRange.lowerBound{ // 判斷是否在當下的 range 裡
            return .leadingMentions
        } else if self.cacheMentionRanges.indices.contains(i + 1) {
            // 判斷是還有下一個 range, 以及在兩個 range 之間
            if (cusorPosistion >= mentionRange.upperBound && cusorPosistion <= self.cacheMentionRanges[i + 1].lowerBound) {
                let offsetIndex = cusorPosistion - self.cacheMentionRanges[i].upperBound
                let tagUserOffset = self.cacheTagUserRanges[i].upperBound + offsetIndex
                return .betweenMention(firstIndex: i, secondIndex: i + 1, offset: tagUserOffset)
            } else {
                return nil
            }
        } else { // 後面無 range
            let offsetIndex = cusorPosistion - self.cacheMentionRanges[i].upperBound
            let tagUserOffset = self.cacheTagUserRanges[i].upperBound + offsetIndex
            return .trallingMentions(lastMentionIndex: i, offset: tagUserOffset)
        }
    }
}

// MARK: - Popover Handler
extension SocialTextView {
    
    private func popoverHandler(text: String) {
        if text == "@" {
            if let lastMentionLocation = self.lastMentionRange?.location { //判斷是否已有 ＠
                self.lastMentionRange = NSRange(location: lastMentionLocation, length: self.getCurrentTypingLocation())
            } else { // 沒有 ＠ 新增一個 range, 跳 popover
                self.lastMentionRange = NSRange(location: self.getCursorPosition(), length: 1)
                self.presentPopover()
                self.mentionPopoverWindow?.searchMention(by: nil)
            }
            
        } else if self.isTypingAfterMention() {
            if let lastMention = self.lastMentionRange {
                let newMentionLength = self.getCurrentTypingLocation() - lastMention.location + 1
                let length = newMentionLength > 0 ? newMentionLength : 0
                self.lastMentionRange = NSRange(location: lastMention.location, length: length)
                self.mentionPopoverWindow?.searchMention(by: self.text.subString(with: lastMentionRange!))
            }
            self.presentPopover()
            
        } else {
            self.lastMentionRange = nil
            self.dismissPopover()
        }
    }
    
    private func isTypingAfterMention() -> Bool {
        // 確定是否在 mention 後面
        guard let lastMentionRange = self.lastMentionRange else { return false }
        return self.getCurrentTypingLocation() > lastMentionRange.location
    }
    
    private func presentPopover() {
        guard !self.isPopoverPresenting else { return }
        self.mentionPopoverWindow?.isHidden = false
        self.isPopoverPresenting = true
        guard self.isInTextView, let height = self.mentionPopoverWindow?.frame.height else { return }
        self.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height + 20.0, right: 0)
    }
    
    private func dismissPopover() {
        self.mentionPopoverWindow?.isHidden = true
        self.isPopoverPresenting = false
        self.contentInset = UIEdgeInsets.zero
    }
    
    open func setMentionPopoverWindow(with frame: CGRect, isInTextView: Bool) {
        self.mentionPopoverWindow = MentionWindow(frame: frame)
        self.isInTextView = isInTextView
        self.mentionPopoverWindow?.delegate = self
    }
    
}

// MARK: - Mention view Delegate
extension SocialTextView: MentionWindowDelegate {
    
    func didSelectedMention(_ mention: MentionUser) {
        self.dismissPopover()
        self.createNewMentionRange(mention)
        self.lastMentionRange = nil
        self.updateTextAttributed()
    }
    
    private func createNewMentionRange(_ mention: MentionUser) {
        let tagUserString = "<tagUser>@\(mention.account)</tagUser>"
        self.mentionDict[mention.account] = mention
        guard let lastMentionRange = self.lastMentionRange else { return }
        switch self.cusorPositionType(isInserting: true) {
        case .leadingMentions:
            self.originText.replaceSubrange(lastMentionRange, withReplacementText: tagUserString)
        case .inTheMention(let mentionIndex):
            self.originText.replaceSubrange(cacheTagUserRanges[mentionIndex], withReplacementText: text)
            self.cacheTagUserRanges.remove(at: mentionIndex)
        case .betweenMention(_, _, let offset):
            let range = NSRange(location: offset - 1, length: lastMentionRange.length)
            self.originText.replaceSubrange(range, withReplacementText: tagUserString)
        case .trallingMentions(_, let offset):
            let range = NSRange(location: offset - 1, length: lastMentionRange.length)
            self.originText.replaceSubrange(range, withReplacementText: tagUserString)
        }
        self.cacheTagUserRanges = ElementBuilder.matchesMentions(form: self.originText)
    }
    
}

// MARK: - Attributed String Handler
extension SocialTextView {
    
    fileprivate func updateTextAttributed(parseText: Bool = true) {
        // clean up previous active elements
        let mutAttrString = NSMutableAttributedString(string: self.originText)
        if parseText {
            self.clearActiveElements()
            let newString = parseTextAndExtractActiveElements(mutAttrString)
            mutAttrString.mutableString.setString(newString)
        }
        self.addLinkAttribute(mutAttrString, with: self.cachedSocialElements)
        self.text = mutAttrString.string
        self.textStorage.setAttributedString(mutAttrString)
        setNeedsDisplay()
    }
    
    fileprivate func clearActiveElements() {
        self.selectedElement = nil
        self.cachedSocialElements.removeAll()
    }
    
    /// use regex check all link ranges
    fileprivate func parseTextAndExtractActiveElements(_ attrString: NSAttributedString) -> String {
        var textString = attrString.string
        var elements: [SocialElement] = []
        elements.append(contentsOf: ElementBuilder.relpaceMentions(form: &textString, with: self.mentionDict))
        elements.append(contentsOf: ElementBuilder.matches(from: textString, withSocialType: .hashtag))
        elements.append(contentsOf: ElementBuilder.matches(from: textString, withSocialType: .url))
        self.cachedSocialElements = elements
        return textString
    }
    
    fileprivate func removeAllAttribute(_ mutAttrString: NSMutableAttributedString) {
        let range = NSRange(location: 0, length: mutAttrString.length)
        var attributes = [NSAttributedString.Key : Any]()
        
        // 保持原本在 storyboard 的顏色字體設定
        attributes[.font] = self.regularFont
        attributes[.foregroundColor] = self.regularColor
        mutAttrString.setAttributes(attributes, range: range)
    }
    
    fileprivate func addLinkAttribute(_ mutAttrString: NSMutableAttributedString, with elements: [SocialElement]) {
        self.removeAllAttribute(mutAttrString)
        // 針對各個元素的顏色字體設定
        for element in elements {
            switch element.type {
            case .mention:
                let id = element.content
                if let user = self.mentionDict[id], user.shouldActive {
                    mutAttrString.setAttributes(
                        self.createAttributes(with: element.type),
                        range: element.range)
                }
            case .hashtag, .url:
                mutAttrString.setAttributes(
                    self.createAttributes(with: element.type),
                    range: element.range)
            }
        }
    }
    
    fileprivate func createAttributes(with socialType: SocialType) -> [NSAttributedString.Key : Any] {
        var attributes = [NSAttributedString.Key : Any]()
        switch socialType {
        case .mention:
            guard self.enableType.contains(socialType) else { break }
            attributes[.font] = mentionFont ?? font!
            attributes[.foregroundColor] = mentionColor
            attributes[.underlineStyle] = mentionUnderLineStyle.rawValue
        case .hashtag:
            guard self.enableType.contains(socialType) else { break }
            attributes[.font] = hashtagFont ?? font!
            attributes[.foregroundColor] = hashtagColor
            attributes[.underlineStyle] = hashtagUnderLineStyle.rawValue
        case .url:
            guard self.enableType.contains(socialType) else { break }
            attributes[.font] = URLFont ?? font!
            attributes[.foregroundColor] = URLColor
            attributes[.underlineStyle] = URLUnderLineStyle.rawValue
        }
        return attributes
    }
}


