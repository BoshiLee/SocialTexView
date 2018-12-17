//
//  SocialTextView.swift
//  SocialTextField
//
//  Created by Boshi Li on 2018/11/20.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import UIKit

enum TypingPosisition {
    case leadingMentions(length: Int)
    case inTheMention(mentionIndex: Int, length: Int)
    case betweenMention(firstIndex: Int, secondIndex: Int, length: Int)
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
    private lazy var mentionDict: MentionDict = MentionDict()
    private var selectedElement: SocialElement?
    private var typingMarkedRanges: NSRange?
    private lazy var uiMentionRanges = [SCTVMentionRange]()
    
    // MARK: - Popover related properties
    private var isPopoverPresenting: Bool = false
    private var lastMentionRange: NSRange?
    private var mentionPopoverWindow: MentionWindow?
    fileprivate var _customizing: Bool = true
    fileprivate var cacheMentionRanges: [NSRange] {
        return self.uiMentionRanges.map { $0.nickNameRange }
    }
    /// 暫存要 po 給後端的 mentions
    fileprivate lazy var cacheMentions = [MentionedUser]()
    fileprivate var postingMentionDict: [String: MentionedUser] {
        var mentionDict = [String: MentionedUser]()
        self.cacheMentions.forEach { mentionDict[$0.account] = $0 }
        return mentionDict
    }
    
    fileprivate lazy var isDelecting = false
    fileprivate lazy var isInTextView = false
    
    // MARK: - Text Storeage
    private lazy var originText: String = ""
    
    // MARK: - Public properties
    open var enableType: [SocialType] = [.mention, .hashtag, .url]
    open var presentingText: String = ""
    open var postingText: String {
        return originText
    }
    
    open weak var scDelegate: SocialTextViewDelegate?
    
    open var postingContent: SCPostingContent {
        get {
            return (self.postingText, self.postingMentionDict)
        }
        set {
            self.resetTextView()
            self.mentionDict = newValue.mentionDict
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
        updateTextAttributed()
    }
    
    open func resetTextView() {
        self.lastMentionRange = nil
        self.text = ""
        self.updateTextAttributed()
        self.clearActiveElements()
        self.cacheMentions.removeAll()
        self.isDelecting = false
        self.isInTextView = false
        self.isPopoverPresenting = false
    }
}

extension SocialTextView: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let char = text.cString(using: String.Encoding.utf8)!
        let typingChar = strcmp(char, "\\b")

        if (typingChar == -92) { // 刪除
            
        } else if (typingChar == -82) { // 換行
            self.dismissPopover()
            self.lastMentionRange = nil

        }
        self.inputTextHandler(range)
        return true
    }
    
    func inputTextHandler(_ typingRange: NSRange) {
        for (i, uiMention) in self.uiMentionRanges.enumerated() {
            guard let positionType = self.getCusorPosistionType(typingRange, Index: i, mentionRange: uiMention.nickNameRange) else { continue }
            switch positionType {
            case .leadingMentions(let length):
                self.resetMentionLoacation(fromIndex: -1, withLength: length)
            case .inTheMention(let mentionIndex, let length):
                self.resetMentionLoacation(fromIndex: mentionIndex, withLength: length)
                self.uiMentionRanges.remove(at: mentionIndex)
                self.removeCandiateFromCache(atIndex: mentionIndex)
            case .betweenMention(let firstIndex, _, let length):
                self.resetMentionLoacation(fromIndex: firstIndex, withLength: length)
            case .trallingMentions:
                break
            }
        }
        print(self.uiMentionRanges)
    }
    
    
    func resetMentionLoacation(fromIndex index: Int, withLength length: Int) {
        if index == -1 {
            for i in 0..<self.uiMentionRanges.count {
                self.uiMentionRanges[i].nickNameRange.location = self.uiMentionRanges[i].nickNameRange.location - length >= 0 ?
                    self.uiMentionRanges[i].nickNameRange.location - length : 0
            }
            return
        }
        guard self.uiMentionRanges.indices.contains(index) else { return }
        for i in 0..<self.uiMentionRanges.count where i > index  {
            self.uiMentionRanges[i].nickNameRange.location = self.uiMentionRanges[i].nickNameRange.location - length >= 0 ?
                self.uiMentionRanges[i].nickNameRange.location - length : 0
        }
    }
    
    func removeCandiateFromCache(atIndex mentionIndex: Int) {
        guard self.uiMentionRanges.indices.contains(mentionIndex) else { return }
        let tagUser = self.uiMentionRanges[mentionIndex].mentionUser.account
        guard let index = self.cacheMentions.firstIndex(where: { $0.account == tagUser }) else { return }
        self.cacheMentions.remove(at: index)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        // place holder handler
        if let placeholderLabel = self.viewWithTag(100) as? UILabel {
            placeholderLabel.isHidden = self.text.count > 0
        }
        
//        var selectedRange = self.selectedRange
        
//        self.typingMarkedRanges = nil
//        self.updateTextAttributed()
//        selectedRange.length = 0
//        self.selectedRange = selectedRange
        self.popoverHandler()
        self.scDelegate?.textViewDidChange(self)
    }
}

// MARK: - Cusor Position Handler
extension SocialTextView {
    
    func getIndexOfCusorInMentionRange(_ range: NSRange) -> Int? {
        return self.cacheMentionRanges.index(where: {
            return range.location >= $0.location && range.location < $0.upperBound
        })
    }
    
    private func getCusorPosistionType(_ typingRange: NSRange, Index i: Int, mentionRange: NSRange) -> TypingPosisition? {
        let cusorLocation = typingRange.location
        if (cusorLocation > mentionRange.lowerBound && cusorLocation < mentionRange.upperBound) { // 判斷是否在當下的 range 裡
            return .inTheMention(mentionIndex: i, length: typingRange.length)
        } else if i == 0, cusorLocation <= mentionRange.lowerBound{ // 判斷是否在第一個 range 前面
            return .leadingMentions(length: typingRange.length)
        } else if self.cacheMentionRanges.indices.contains(i + 1) {
            if (cusorLocation >= mentionRange.upperBound && cusorLocation < self.cacheMentionRanges[i + 1].lowerBound) {
                return .betweenMention(firstIndex: i, secondIndex: i + 1, length: typingRange.length)
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
        if self.isCurrentTyping(is: "@") {
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
        print(self.uiMentionRanges.count)
    }
    
    private func createNewMentionRange(_ mention: MentionedUser) {
        self.mentionDict[mention.account] = mention
        self.cacheMentions.append(mention)
        guard let lastMentionRange = self.lastMentionRange else { return }
        let mentionString = "@\(mention.nickName)"
        self.text = self.text.nsString.replacingCharacters(in: lastMentionRange, with: mentionString) as String
        let mentionRange = SCTVMentionRange(nickNameRange: NSRange(location: lastMentionRange.location, length: mentionString.nsString.length), mentionUser: mention)
        self.uiMentionRanges.append(mentionRange)
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
        self.text = mutAttrString.string
        self.presentingText = self.text
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
