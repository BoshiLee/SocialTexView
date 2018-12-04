//
//  MentionCandidateCellViewModel.swift
//  SocialTextField
//
//  Created by Boshi Li on 2018/11/20.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import UIKit

class MentionCandidateCellViewModel: TableCellViewModelProtocol {
    
    let photoImageURL: URL
    let nickName: String
    let id: String
    
    init(photoImageURL: URL, nickName: String, id: String) {
        self.photoImageURL = photoImageURL
        self.nickName = nickName
        self.id = id
    }
    
    func dequeue(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MentionCandidateCell", for: indexPath) as? MentionCandidateCell else { return UITableViewCell() }
        cell.configure(withViewModel: self)
        return cell
    }
    
}
