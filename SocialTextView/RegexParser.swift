//
//  RegexParser.swift
//  SocialLabel
//
//  Created by Boshi Li on 2018/11/14.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import Foundation

enum RexgexPattern: String {
    
    case hashtag = "#(.+?)(?=[\\s]|$)"
    case mention = "(\\<tagUser\\>\\@)(.+?)(\\<\\/tagUser\\>)"
    case url = "(?:http(s)?\\:\\/\\/|www\\.)(.+?)(?=[\\s]|$)"
    
    var expression: NSRegularExpression? {
        return try? NSRegularExpression(pattern: self.rawValue, options: [.caseInsensitive])
    }
}

