//
//  MentionsViewModel.swift
//  SocialTextField
//
//  Created by Boshi Li on 2018/11/20.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import UIKit

protocol MentionsPresentable: AnyObject {
    func didGetMentions()
    func didSelectedMention(_ mention: MentionUser)
}

class MentionsViewModel: NSObject {
    
    lazy var cellViewModels = [MentionCandidateCellViewModel]()
    
    weak var presenter: MentionsPresentable!
    
    init(presenter: MentionsPresentable) {
        self.presenter = presenter
        
        super.init()
    }
    
    func searchMentions(by keyword: String?) {
        
        self.cellViewModels.append(MentionCandidateCellViewModel(photoImageURL: URL(string: "http://123.com")!, nickName: "Boshi Li", id: "boshilee"))
        self.presenter.didGetMentions()
    }
    
}

extension MentionsViewModel: UITableViewDataSource, UITableViewDelegate {
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.cellViewModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.cellViewModels[indexPath.row].cellInstance(cell: MentionCandidateCell.self, tableView: tableView, atIndexPath: indexPath)
        cell.configure(withViewModel: self.cellViewModels[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellVM = self.cellViewModels[indexPath.row]
        let metion = MentionUser(
            account: cellVM.id,
            nickName: cellVM.nickName,
            shouldActiveInt: 1
        )
        self.presenter.didSelectedMention(metion)
    }
}
