//
//  ViewController.swift
//  SocialTextField
//
//  Created by Boshi Li on 2018/11/19.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITextViewDelegate {
    
    var mentionPopoverWindow: MentionWindow?
    
    
    @IBOutlet weak var socialTextView: SocialTextView! {
        didSet {
            let activeFont = UIFont.boldSystemFont(ofSize: 14.0)
            self.socialTextView.regularFont = activeFont
            self.socialTextView.hashtagColor = .tagBlue
            self.socialTextView.hashtagFont = activeFont
            self.socialTextView.URLColor = .textBlack
            self.socialTextView.URLUnderLineStyle = .single
            self.socialTextView.URLFont = activeFont
            self.socialTextView.mentionColor = .tagBlue
            self.socialTextView.mentionFont = activeFont
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.setMentionPopoverWindow()
    }
    
    
    func setMentionPopoverWindow() {
        
        let textViewBounds = self.socialTextView.frame
        let size = CGSize(width: textViewBounds.width * 0.95,
                          height: textViewBounds.height * 0.5)
        let frame = CGRect(
            x: textViewBounds.minX + ((self.socialTextView.bounds.width - size.width) / 2),
            y: textViewBounds.midY,
            width: size.width,
            height: size.height
        )
        self.socialTextView.setMentionPopoverWindow(with: frame, isInTextView: true)
    }
    
}
