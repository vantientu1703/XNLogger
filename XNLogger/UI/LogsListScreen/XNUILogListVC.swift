//
//  NLLogListVC.swift
//  XNLogger
//
//  Created by Sunil Sharma on 16/08/19.
//  Copyright © 2019 Sunil Sharma. All rights reserved.
//

import UIKit

class XNUILogListVC: XNUIBaseViewController {
    
    @IBOutlet weak var logListTableView: UITableView!
    @IBOutlet weak var emptyMsgLabel: UILabel!
    @IBOutlet weak var searchContainerHeight: NSLayoutConstraint!
    @IBOutlet weak var searchContainerView: UIView!
    @IBOutlet weak var logSearchBar: UISearchBar!
    
    let maxSearchBarHeight: CGFloat = 42;
    let minSearchBarHeight: CGFloat = 0;
    
    /// The last known scroll position
    var previousScrollOffset: CGFloat = 0
    
    /// The last known height of the scroll view content
    var previousScrollViewHeight: CGFloat = 0
    
    var viewModeBarButton: UIButton = UIButton()
    
    private var logsDataDict: [String: XNUILogInfo] {
        return XNUIManager.shared.getLogsDataDict()
    }
    
    private var logsIdArray: [String] {
        return XNUIManager.shared.getLogsIdArray()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureViews()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateLoggerUI), name: .logDataUpdate, object: nil)
        updateLoggerUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.headerView?.setTitle("XNLogger", attributes: [.foregroundColor: XNUIAppColor.navTint, .font: UIFont.systemFont(ofSize: 24, weight: .semibold)])
    }
    
    func configureViews() {
        let closeButton = helper.createNavButton(
            imageName: "close",
            imageInsets: UIEdgeInsets(top: 15, left: 25, bottom: 9, right: 5))
        closeButton.addTarget(self, action: #selector(dismissNetworkUI), for: .touchUpInside)
        
        viewModeBarButton = helper.createNavButton(
            imageName: "minimise",
            imageInsets: UIEdgeInsets(top: 10, left: 6, bottom: 7, right: 12))
        viewModeBarButton.addTarget(self, action: #selector(upadteViewMode), for: .touchUpInside)
        
        self.headerView?.addRightBarItems([closeButton])
        self.headerView?.addleftBarItems([viewModeBarButton])
        
        self.logListTableView.tableFooterView = UIView()
        self.logListTableView.register(ofType: XNUILogListTableViewCell.self)
        self.logListTableView.dataSource = self
        self.logListTableView.delegate = self
        self.emptyMsgLabel.text = "No network logs found!"
        
        self.searchContainerHeight.constant = 0
        
    }
    
    @objc func dismissNetworkUI() {
        XNUIManager.shared.dismissNetworkUI()
    }
    
    @objc func upadteViewMode() {
        let enableMiniView = !XNUIManager.shared.isMiniModeActive
        updateViewModeIcon(isMiniViewEnabled: enableMiniView)
        XNUIManager.shared.updateViewMode(enableMiniView: enableMiniView)
    }
    
    func updateViewModeIcon(isMiniViewEnabled: Bool) {
        
        UIView.transition(with: self.viewModeBarButton, duration: 0.3, options: .transitionCrossDissolve, animations: {
            if isMiniViewEnabled {
                self.viewModeBarButton.setImage(UIImage(named: "maximise", in: Bundle.current(), compatibleWith: nil), for: .normal)
            } else {
                self.viewModeBarButton.setImage(UIImage(named: "minimise", in: Bundle.current(), compatibleWith: nil), for: .normal)
            }
        }, completion: nil)
        
    }
    
    /**
     Return index for `logsIdArray` w.r.t to UITableView rows.
     */
    func getLogIdArrayIndex(for indexPath: IndexPath) -> Int? {
        let logIds = self.logsIdArray
        if logIds.count > indexPath.row {
            return (logIds.count - 1) - indexPath.row
        }
        return nil
    }
    
    /**
     Return `XNLogData` for given index path.
     */
    func getLogData(indexPath: IndexPath) -> XNUILogInfo? {
        if let index = getLogIdArrayIndex(for: indexPath) {
            return logsDataDict[logsIdArray[index]]
        }
        return nil
    }
    
    @objc func updateLoggerUI() {
        DispatchQueue.main.async {
            self.logListTableView.reloadData()
            self.emptyMsgLabel.isHidden = !self.logsIdArray.isEmpty
        }
    }
    
    deinit {
        print("\(type(of: self)) \(#function)")
        NotificationCenter.default.removeObserver(self, name: .logDataUpdate, object: nil)
    }
}

extension XNUILogListVC: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logsIdArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: XNUILogListTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        if let logData = getLogData(indexPath: indexPath) {
            cell.configureViews(withData: logData)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            if let index = getLogIdArrayIndex(for: indexPath) {
                XNUIManager.shared.removeLogAt(index: index)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                if logsIdArray.isEmpty {
                    updateLoggerUI()
                }
            }
        }
    }
}

extension XNUILogListVC: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let logData = getLogData(indexPath: indexPath),
            let detailController = XNUILogDetailVC.instance() {
            detailController.logInfo = logData
            self.navigationController?.pushViewController(detailController, animated: true)
        }
    }
}

extension XNUILogListVC: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        
    }
}

extension XNUILogListVC {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        defer {
            self.previousScrollViewHeight = scrollView.contentSize.height
            self.previousScrollOffset = scrollView.contentOffset.y
        }
        
        let scrollSizeDiff = scrollView.contentSize.height - self.previousScrollViewHeight
        // If the scroll was caused by the height of the scroll view changing, we want to do nothing.
        guard scrollSizeDiff == 0 else { return }
        
        let scrollDiff = scrollView.contentOffset.y - self.previousScrollOffset
        let absoluteTop: CGFloat = 0
        let absoluteBottom: CGFloat = max((scrollView.contentSize.height - scrollView.frame.size.height), scrollView.contentSize.height)
        
        let isScrollingDown = scrollDiff > 0 && scrollView.contentOffset.y > absoluteTop
        let isScrollingUp = scrollDiff < 0 && scrollView.contentOffset.y < absoluteBottom
        
        var newHeight = self.searchContainerHeight.constant
        // Display search bar when scroll view is at top
        if isScrollingUp && scrollView.contentOffset.y < 0 {
            newHeight = min(self.maxSearchBarHeight, self.searchContainerHeight.constant + abs(scrollDiff))
        }
        
        if isScrollingDown {
            newHeight = max(self.minSearchBarHeight, self.searchContainerHeight.constant - abs(scrollDiff))
        }
        
        if newHeight != self.searchContainerHeight.constant {
            self.searchContainerHeight.constant = newHeight
            updateSearchBarUI()
            self.setScrollPosition(self.previousScrollOffset)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate == false {
            scrollViewDidStopScrolling()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidStopScrolling()
    }
    
    func scrollViewDidStopScrolling() {
        let range = self.maxSearchBarHeight - self.minSearchBarHeight
        let midPoint = self.minSearchBarHeight + (range * 0.6)
        
        if self.searchContainerHeight.constant > midPoint {
            showSearchBar()
        } else {
            hideSearchBar()
        }
    }
    
    func setScrollPosition(_ position: CGFloat) {
        self.logListTableView.contentOffset = CGPoint(x: self.logListTableView.contentOffset.x, y: position)
    }
    
    func hideSearchBar() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .curveEaseInOut], animations: {
            self.searchContainerHeight.constant = self.minSearchBarHeight
            self.updateSearchBarUI()
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func showSearchBar() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .curveEaseInOut], animations: {
            self.searchContainerHeight.constant = self.maxSearchBarHeight
            self.updateSearchBarUI()
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func updateSearchBarUI() {
        let range = self.maxSearchBarHeight - self.minSearchBarHeight
        let openAmount = self.searchContainerHeight.constant - self.minSearchBarHeight
        let percentage = openAmount / range
        if percentage < 0.6 {
            self.logSearchBar.searchTextField.alpha = 0
        } else {
            self.logSearchBar.searchTextField.alpha = percentage
        }
        self.logSearchBar.alpha = percentage
    }
}

