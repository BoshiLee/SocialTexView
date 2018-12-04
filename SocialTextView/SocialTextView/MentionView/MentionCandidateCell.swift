//
//  MentionCandidateCell.swift
//  SocialTextField
//
//  Created by Boshi Li on 2018/11/20.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import UIKit

class MentionCandidateCell: UITableViewCell {

    @IBOutlet weak var memberImageView: UIImageView!
    @IBOutlet weak var nickNameLabel: UILabel!
    
    func configure(withViewModel viewModel: MentionCandidateCellViewModel) {
        self.nickNameLabel.text = viewModel.nickName
    }
    
}
