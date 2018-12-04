//
//  UITableViewHelper.swift
//  FlowButtonTable
//
//  Created by Boshi Li on 04/02/2018.
//  Copyright © 2018 Boshi Li. All rights reserved.
//

import UIKit

extension UITableView {
    
    func register<T: UITableViewCell>(_: T.Type) {
        let identifier = String(describing: T.self)
        if Bundle.main.path(forResource: identifier, ofType: "nib") != nil {
            let nib = UINib(nibName: identifier, bundle: nil)
            register(nib, forCellReuseIdentifier: identifier)
        } else {
            register(T.self, forCellReuseIdentifier: identifier)
        }
    }
    
    func dequeue<T: UITableViewCell>(_: T.Type, indexPath: IndexPath) -> T {
        let identifier = String(describing: T.self)
        guard let cell = dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? T else {
            return T.init()
        }
        return cell
    }
    
    func registerHeaderFooter<T: UITableViewHeaderFooterView>(_: T.Type) {
        let identifier = String(describing: T.self)
        if Bundle.main.path(forResource: identifier, ofType: "nib") != nil {
            let nib = UINib(nibName: identifier, bundle: nil)
            register(nib, forHeaderFooterViewReuseIdentifier: identifier)
        } else {
            register(T.self, forHeaderFooterViewReuseIdentifier: identifier)
        }
    }
    
    func dequeueHeaderFooter<T: UITableViewHeaderFooterView>(_: T.Type) -> T {
        let identifier = String(describing: T.self)
        guard let view = dequeueReusableHeaderFooterView(withIdentifier: identifier) as? T else {
            return T.init()
        }
        return view
    }
    
}

protocol TableCellViewModelProtocol {
    func cellInstance<T: UITableViewCell>(cell: T.Type, tableView: UITableView, atIndexPath indexPath: IndexPath) -> T
}

extension TableCellViewModelProtocol {
    func cellInstance<T: UITableViewCell>(cell: T.Type, tableView: UITableView, atIndexPath indexPath: IndexPath) -> T {
        tableView.register(cell)
        let cell = tableView.dequeue(cell.self, indexPath: indexPath)
        return cell
    }
}
