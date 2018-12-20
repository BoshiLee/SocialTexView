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
    case betweenMention(firstIndex: Int, secondIndex: Int)
    case trallingMentions
}

typealias SCPostingContent = (content: String, mentionDict: MentionDict)

protocol SocialTextViewDelegate: AnyObject {
    func textViewDidChange(_ textView: SocialTextView)
}

class SocialTextView: UITextView {
    
    // MARK: - override UILabel properties
    
    override open var textAlignment: NSTextAlignment {
        didSet { updateTextAttributed(parseText: false)}
    }
    
    // MARK: - Inspectable Properties
    @IBInspectable open var regularFont: UIFont = .systemFont(ofSize: 17.0) {
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
    private var cacheMarkedTypingRanges: NSRange?
    private lazy var mentionDict: MentionDict = MentionDict()
    private var selectedElement: SocialElement?
    lazy var uiMentionRanges = [SCTVMentionRange]()
    
    // MARK: - Popover related properties
    private var isPopoverPresenting: Bool = false
    private var lastMentionRange: NSRange?
    private var mentionPopoverWindow: MentionWindow?
    fileprivate var _customizing: Bool = true
    fileprivate var cacheMentionRanges: [NSRange] {
        return self.uiMentionRanges.map { $0.nickNameRange }
    }
    /// 暫存要 po 給後端的 mentions
    fileprivate lazy var mentionedUsersCache = [MentionedUser]()
    fileprivate var postingMentionDict: [String: MentionedUser] {
        var mentionDict = [String: MentionedUser]()
        self.mentionedUsersCache.forEach { mentionDict[$0.account] = $0 }
        return mentionDict
    }
    
    fileprivate lazy var isDelecting = false
    fileprivate lazy var isInTextView = false
    
    
    
    // MARK: - Public properties
    open var enableType: [SocialType] = [.mention, .hashtag, .url]
    open weak var scDelegate: SocialTextViewDelegate?
    
    open var postingContent: SCPostingContent {
        get {
            return (self.postingText, self.postingMentionDict)
        }
        set {
            self.resetTextView()
            var presentingText = newValue.content
            self.uiMentionRanges = self.setText(fromOriginText: &presentingText, mentionDict: newValue.mentionDict)
            self.mentionDict = newValue.mentionDict
            self.text = presentingText
            self.updateTextAttributed()
        }
    }
    
    // MARK: - Place Holder Properties
    override public var bounds: CGRect {
        didSet {
            self.resizePlaceholder()
        }
    }
    
    private var placeholderColor: UIColor { return #colorLiteral(red: 0.6705882353, green: 0.6705882353, blue: 0.6705882353, alpha: 1) }
    
    /// The UITextView placeholder text
    @IBInspectable public var placeholder: String? {
        get {
            var placeholderText: String?
            
            if let placeholderLabel = self.viewWithTag(100) as? UILabel {
                placeholderText = placeholderLabel.text
            }
            
            return placeholderText
        }
        set {
            if let placeholderLabel = self.viewWithTag(100) as! UILabel? {
                placeholderLabel.text = newValue
                placeholderLabel.sizeToFit()
            } else {
                self.addPlaceholder(newValue!, color: self.placeholderColor)
            }
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _customizing = false
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        self.delegate = self
        self.autocorrectionType = .no
        updateTextAttributed()
    }
    
    open func resetTextView() {
        self.lastMentionRange = nil
        self.text = ""
        self.uiMentionRanges.removeAll()
        self.updateTextAttributed()
        self.clearActiveElements()
        self.mentionedUsersCache.removeAll()
        self.isDelecting = false
        self.isInTextView = false
        self.isPopoverPresenting = false
    }
}

extension SocialTextView: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        // place holder handler
        if let placeholderLabel = self.viewWithTag(100) as? UILabel {
            placeholderLabel.isHidden = self.text.count > 0
        }
        
        guard self.markedTypingRange == nil else {
            if let cacheRange = self.cacheMarkedTypingRanges {
                if cacheRange.length <= self.markedTypingRange!.length {
                    self.cacheMarkedTypingRanges = self.markedTypingRange
                }
            } else {
                self.cacheMarkedTypingRanges = self.markedTypingRange
            }
            return
        }
        self.cacheMarkedTypingRanges = nil
        self.updateTextAttributed()
        self.popoverHandler()
        self.scDelegate?.textViewDidChange(self)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let char = text.cString(using: String.Encoding.utf8)!
        let typingChar = strcmp(char, "\\b")
        let isInserting = (typingChar == -92) ? false : true // false 為目前是刪除
        if (typingChar == -82) { // 換行
            self.dismissPopover()
            self.lastMentionRange = nil
        }
        
        return self.inputTextHandler(range, replaceText: text, isInserting: isInserting)
    }
    
    func inputTextHandler(_ typingRange: NSRange, replaceText: String, isInserting: Bool) -> Bool {
        if self.selectedRange.length > 0, !self.findRanges(inSelectedRange: self.selectedRange).isEmpty {
            self.resetAllMentionRanges(withSelectedRange: self.selectedRange, replaceText: replaceText, isInserting: isInserting)
            return true
        }
        for (i, uiMention) in self.uiMentionRanges.enumerated() {
            guard let positionType = self.getCusorPosistionType(typingRange, Index: i, mentionRange: uiMention.nickNameRange, isInserting: isInserting) else { continue }
            let length = typingRange.length
            let newRange = NSRange(location: typingRange.location, length: length)
            switch positionType {
            case .leadingMentions:
                self.resetMentionLoacations(fromIndex: -1, withRange: newRange, replaceText: replaceText, isInserting: isInserting)
                return true
            case .inTheMention(let mentionIndex):
                self.editMentionRange(at: mentionIndex, replacementText: replaceText)
                return false
            case .betweenMention(let firstIndex, _):
                self.resetMentionLoacations(fromIndex: firstIndex, withRange: newRange, replaceText: replaceText, isInserting: isInserting)
                return true
            case .trallingMentions:
                return true
            }
        }
        return true
    }
    
    func removeMentionRange(at index: Int) -> (NSRange, String)? {
        guard self.uiMentionRanges.indices.contains(index) else { return nil}
        let nickNameRange = self.uiMentionRanges[index].nickNameRange
        self.resetMentionLoacations(fromIndex: index, withRange: nickNameRange, replaceText: "", isInserting: false)
        self.uiMentionRanges.remove(at: index)
        self.removeCandiateFromCache(withMentionedUser: self.uiMentionRanges[index].mentionUser)
        var newText = self.text!
        newText.removeSubrange(nickNameRange)
        return (nickNameRange, newText)
    }
    
    func editMentionRange(at index: Int, replacementText text: String) {
        guard self.uiMentionRanges.indices.contains(index) else { return }
        let nickNameRange = self.uiMentionRanges[index].nickNameRange
        self.resetMentionLoacations(fromIndex: index, withRange: nickNameRange, replaceText: text, isInserting: true)
        self.removeCandiateFromCache(withMentionedUser: self.uiMentionRanges[index].mentionUser)
        self.uiMentionRanges.remove(at: index)
        self.replaceText(range: nickNameRange, replacementText: text)
        self.updateTextAttributed()
    }
    
    func replaceText(range: NSRange, replacementText text: String) {
        var cusorRange = self.selectedRange
        cusorRange.location = range.location + text.nsString.length
        self.text = self.text.nsString.replacingCharacters(in: range, with: text)
        self.selectedRange = cusorRange
    }
    
    func resetMentionLoacations(fromIndex index: Int, withRange range: NSRange, replaceText: String, isInserting: Bool) {
        if index == -1, !self.uiMentionRanges.isEmpty {
            for i in 0..<self.uiMentionRanges.endIndex {
                self.resetMentionLocation(atIndex: i, range: range, replcaceText: replaceText, isInserting: isInserting)
            }
            return
        }
        guard self.uiMentionRanges.indices.contains(index) else { return }
        for i in 0..<self.uiMentionRanges.count where i > index  {
            self.resetMentionLocation(atIndex: i, range: range, replcaceText: replaceText, isInserting: isInserting)
        }
    }
    
    func resetMentionLocation(atIndex i: Int, range: NSRange, replcaceText: String, isInserting: Bool) {
        guard self.uiMentionRanges.indices.contains(i) else { return }
        if isInserting, let cacheRange = self.cacheMarkedTypingRanges, cacheRange.location == range.location {
            let newlocation = self.uiMentionRanges[i].nickNameRange.location - cacheRange.length + replcaceText.nsString.length
            self.uiMentionRanges[i].nickNameRange.location = newlocation
        } else {
            let newLocation = self.uiMentionRanges[i].nickNameRange.location - range.length + replcaceText.nsString.length
            self.uiMentionRanges[i].nickNameRange.location = newLocation
        }
        
    }
    
    func removeCandiateFromCache(withMentionedUser mentionUser: MentionedUser) {
        guard let index = self.mentionedUsersCache.firstIndex(where: { $0.account == mentionUser.account }) else { return }
        self.mentionedUsersCache.remove(at: index)
    }
    
    func resetAllMentionRanges(withSelectedRange range: NSRange, replaceText: String, isInserting: Bool) {
        self.removeAllMentionRange(inSelectedRange: range)
        for (i, uiRange) in self.uiMentionRanges.enumerated()
            where uiRange.nickNameRange.location > range.upperBound {
                self.resetMentionLocation(atIndex: i, range: range, replcaceText: replaceText, isInserting: isInserting)
        }
    }
    
    func removeAllMentionRange(inSelectedRange range: NSRange) {
        let uiRangesInSelectedRange = self.findRanges(inSelectedRange: range)
        uiRangesInSelectedRange.forEach { [unowned self] (uiRange) in
            self.uiMentionRanges.removeAll { $0.nickNameRange.location == uiRange.nickNameRange.location }
            self.removeCandiateFromCache(withMentionedUser: uiRange.mentionUser)
        }
    }
    
    func findRanges(inSelectedRange range: NSRange) -> [SCTVMentionRange] {
        return self.uiMentionRanges.filter {
            let nickNameRange = $0.nickNameRange
            let upperBound = nickNameRange.upperBound - 1
            let tralling =
                nickNameRange.location < range.location &&
                    upperBound > range.location &&
                    upperBound < range.upperBound - 1
            
            let inner =
                nickNameRange.location >= range.location && upperBound <= range.upperBound - 1
            
            let leading =
                nickNameRange.location > range.location &&
                    upperBound > range.upperBound - 1 &&
                    nickNameRange.location < range.upperBound - 1
            
            return leading || inner || tralling
        }
    }
    
}

// MARK: - Cusor Position Handler
extension SocialTextView {
    
    private func getCusorPosistionType(_ typingRange: NSRange, Index i: Int, mentionRange: NSRange, isInserting: Bool) -> TypingPosisition? {
        let cusorLocation = self.getCursorPosition()
        //        print(, cusorLocation)
        let upperBound = isInserting ? mentionRange.upperBound - 1 : mentionRange.upperBound
        if (cusorLocation > mentionRange.location && cusorLocation <= upperBound) { // 判斷是否在當下的 range 裡
            return .inTheMention(mentionIndex: i)
        } else if i == 0, cusorLocation <= mentionRange.location { // 判斷是否在第一個 range 前面
            return .leadingMentions
        } else if self.cacheMentionRanges.indices.contains(i + 1) {
            if (cusorLocation > upperBound - 1 && cusorLocation <= self.cacheMentionRanges[i + 1].location) {
                return .betweenMention(firstIndex: i, secondIndex: i + 1)
            } else {
                return nil
            }
        } else { // 後面無 range
            return .trallingMentions
        }
    }
    
}

// MARK: - Popover Handler
extension SocialTextView {
    
    private func popoverHandler() {
        if self.isCurrentTyping(is: "@"),
            !self.uiMentionRanges.contains(where:
                { [unowned self] in $0.nickNameRange.location == self.getCurrentTypingLocation() })
        {
            if let lastMentionRange = self.lastMentionRange { //判斷是否已有 ＠
                let newMentionRange = self.append(ToLastMentionRange: lastMentionRange)
                self.lastMentionRange = newMentionRange // 刪除時 substring 對不起來
                guard let subString = self.text.subString(with: newMentionRange) else { return }
                self.mentionPopoverWindow?.searchMention(by: subString)
            } else { // 沒有 ＠ 新增一個 range, 跳 popover
                self.lastMentionRange = NSRange(location: self.getCurrentTypingLocation(), length: 1)
                self.presentPopover()
                self.mentionPopoverWindow?.searchMention(by: nil)
            }
        } else if self.isTypingAfterMention() {
            if let lastMentionRange = self.lastMentionRange {
                let newMentionRange = self.append(ToLastMentionRange: lastMentionRange)
                self.lastMentionRange = newMentionRange
                guard let subString = self.text.subString(with: newMentionRange) else { return }
                self.mentionPopoverWindow?.searchMention(by: subString)
            }
            self.presentPopover()
        } else {
            self.lastMentionRange = nil
            self.dismissPopover()
        }
    }
    
    private func append(ToLastMentionRange lastMentionRange: NSRange) -> NSRange {
        let newMentionLength = getCursorPosition() - lastMentionRange.location
        let newRange = NSRange(location: lastMentionRange.location, length: newMentionLength)
        return newRange
    }
    
    private func isTypingAfterMention() -> Bool {
        // 確定是否在 mention 後面
        guard let lastMentionRange = self.lastMentionRange else { return false }
        return self.getCursorPosition() > lastMentionRange.location
    }
    
    private func presentPopover() {
        guard !self.isPopoverPresenting else { return }
        self.mentionPopoverWindow?.isHidden = false
        self.isPopoverPresenting = true
        guard self.isInTextView, let height = self.mentionPopoverWindow?.frame.height else { return }
        self.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height + height * 0.5, right: 0)
    }
    
    open func dismissPopover() {
        self.mentionPopoverWindow?.isHidden = true
        self.isPopoverPresenting = false
        self.contentInset = .zero
    }
    
    open func setMentionPopoverWindow(with frame: CGRect, isInTextView: Bool) {
        guard self.mentionPopoverWindow == nil else { return }
        self.mentionPopoverWindow = MentionWindow(frame: frame)
        self.isInTextView = isInTextView
        self.mentionPopoverWindow?.delegate = self
    }
    
    open func resetPositionForMentionPopover(_ frame: CGRect) {
        guard self.mentionPopoverWindow != nil else { return }
        self.mentionPopoverWindow?.frame = frame
    }
    
    override func resignFirstResponder() -> Bool {
        self.dismissPopover()
        self.lastMentionRange = nil
        return super.resignFirstResponder()
    }
    
}

// MARK: - Mention view Delegate
extension SocialTextView: MentionWindowDelegate {
    
    func didSelectedMention(_ mention: MentionedUser) {
        self.dismissPopover()
        self.createNewMentionRange(mention)
        self.lastMentionRange = nil
        self.updateTextAttributed()
        UIImpactFeedbackGenerator().impactOccurred()
    }
    
    private func createNewMentionRange(_ mentioned: MentionedUser) {
        self.mentionDict[mentioned.account] = mentioned
        self.mentionedUsersCache.append(mentioned)
        guard let lastMentionRange = self.lastMentionRange else { return }
        let mentionString = "@\(mentioned.nickName) "
        self.appendNewMention(by: mentioned, mentionString: mentionString, lastMentionRange: lastMentionRange)
        self.replaceText(range: lastMentionRange, replacementText: mentionString)
    }
    
    private func appendNewMention(by mentioned: MentionedUser, mentionString: String, lastMentionRange: NSRange) {
        let mentionRange = SCTVMentionRange(nickNameRange: NSRange(location: lastMentionRange.location, length: mentionString.nsString.length - 1), mentionUser: mentioned)
        guard !self.uiMentionRanges.isEmpty else {
            self.uiMentionRanges.append(mentionRange)
            return
        }
        for (i, uiMention) in self.uiMentionRanges.enumerated() {
            guard let positionType = self.getCusorPosistionType(lastMentionRange, Index: i, mentionRange: uiMention.nickNameRange, isInserting: true) else { continue }
            switch positionType {
            case .leadingMentions:
                self.resetMentionLoacations(fromIndex: -1, withRange: lastMentionRange, replaceText: mentionString, isInserting: true)
                self.uiMentionRanges.insert(mentionRange, at: 0)
                return
            case .inTheMention(_):
                return
            case .betweenMention(let headIndex, let behindIndex):
                self.resetMentionLoacations(fromIndex: headIndex, withRange: lastMentionRange, replaceText: mentionString, isInserting: true)
                self.uiMentionRanges.insert(mentionRange, at: behindIndex)
                return
            case .trallingMentions:
                self.uiMentionRanges.append(mentionRange)
                return
            }
        }
    }
    
}

// MARK: - Attributed String Handler
extension SocialTextView {
    
    fileprivate func updateTextAttributed(parseText: Bool = true) {
        // clean up previous active elements
        let mutAttrString = NSMutableAttributedString(string: self.text)
        if parseText {
            self.clearActiveElements()
            let newString = parseTextAndExtractActiveElements(mutAttrString)
            mutAttrString.mutableString.setString(newString)
        }
        self.addLinkAttribute(mutAttrString, with: self.cachedSocialElements)
        self.textStorage.setAttributedString(mutAttrString)
        setNeedsDisplay()
    }
    
    fileprivate func clearActiveElements() {
        self.selectedElement = nil
        self.cachedSocialElements.removeAll()
    }
    
    /// use regex check all link ranges
    fileprivate func parseTextAndExtractActiveElements(_ attrString: NSAttributedString) -> String {
        let textString = attrString.string
        var elements: [SocialElement] = []
        let mentionElements = self.uiMentionRanges.map {
            SocialElement(type: .mention, content: $0.mentionUser.account, range: $0.nickNameRange)
        }
        elements.append(contentsOf: mentionElements)
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

// MARK: - Place Holder Handler
extension SocialTextView {
    /// Resize the placeholder UILabel to make sure it's in the same position as the UITextView text
    private func resizePlaceholder() {
        if let placeholderLabel = self.viewWithTag(100) as! UILabel? {
            let labelX = self.textContainer.lineFragmentPadding
            let labelY = self.textContainerInset.top - 2
            let labelWidth = self.frame.width - (labelX * 2)
            let labelHeight = placeholderLabel.frame.height
            
            placeholderLabel.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
        }
    }
    
    /// Adds a placeholder UILabel to this UITextView
    private func addPlaceholder(_ placeholderText: String, color: UIColor) {
        let placeholderLabel = UILabel()
        
        placeholderLabel.text = placeholderText
        placeholderLabel.sizeToFit()
        
        placeholderLabel.font = self.font
        placeholderLabel.textColor = color
        placeholderLabel.tag = 100
        
        placeholderLabel.isHidden = self.text.count > 0
        
        self.addSubview(placeholderLabel)
        self.resizePlaceholder()
    }
}
