/**
      This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
      Copyright © Adguard Software Limited. All rights reserved.

      Adguard for iOS is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 3 of the License, or
      (at your option) any later version.

      Adguard for iOS is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
      along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
*/

import UIKit

protocol ActivityViewControllerDelegate: class {
    func hideTitle()
    func showTitle()
}

class ActivityViewController: UITableViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var activityTitle: ThemableLabel!
    
    @IBOutlet weak var changePeriodTypeButton: UIButton!
    
    @IBOutlet weak var requestsNumberLabel: ThemableLabel!
    @IBOutlet weak var encryptedNumberLabel: UILabel!
    @IBOutlet weak var dataSavedLabel: UILabel!
    @IBOutlet weak var companiesNumberLabel: ThemableLabel!
    
    @IBOutlet weak var mostActiveButton: RoundRectButton!
    @IBOutlet weak var mostActiveLabel: ThemableLabel!
    @IBOutlet weak var mostActiveCompany: ThemableLabel!
    @IBOutlet weak var rightArrowImageView: UIImageView!
    
    @IBOutlet weak var recentActivityLabel: ThemableLabel!
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var placeHolderLabel: ThemableLabel!
    
    @IBOutlet var themableButtons: [ThemableButton]!
    @IBOutlet var themableLabels: [ThemableLabel]!
    
    // MARK: - Outlet views for tableview
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet var sectionHeaderView: UIView!
    @IBOutlet var tableHeaderView: UIView!
    @IBOutlet weak var tableFooterView: UIView!
    
    
    // MARK: - Services
    
    private let theme: ThemeServiceProtocol = ServiceLocator.shared.getService()!
    private let configuration: ConfigurationService = ServiceLocator.shared.getService()!
    private let resources: AESharedResourcesProtocol = ServiceLocator.shared.getService()!
    private let activityStatisticsService: ActivityStatisticsServiceProtocol = ServiceLocator.shared.getService()!
    private let dnsTrackersService: DnsTrackerServiceProtocol = ServiceLocator.shared.getService()!
    private let domainsParserService: DomainsParserServiceProtocol = ServiceLocator.shared.getService()!
    
    // MARK: - Notifications
    
    private var themeToken: NotificationToken?
    private var keyboardShowToken: NotificationToken?
    private var resetStatisticsToken: NotificationToken?
    private var advancedModeToken: NSKeyValueObservation?
    private var resetSettingsToken: NotificationToken?
    
    // MARK: - Public variables
    
    var requestsModel: DnsRequestLogViewModel?
    weak var delegate: ActivityViewControllerDelegate?
    
    // MARK: - Private variables
    
    private var titleInNavBarIsShown = false
    
    private let activityModel: ActivityStatisticsModelProtocol
    private var statisticsModel: ChartViewModelProtocol = ServiceLocator.shared.getService()!
    
    private let activityTableViewCellReuseId = "ActivityTableViewCellId"
    private let showDnsContainerSegueId = "showDnsContainer"
    private let showMostActiveCompaniesSegueId = "showMostActiveCompaniesId"
    
    private var selectedRecord: DnsLogRecordExtended?
    private var mostRequestedCompanies: [CompanyRequestsRecord] = []
    private var companiesNumber = 0
    
    // MARK: - ViewController life cycle
    
    required init?(coder: NSCoder) {
        activityModel = ActivityStatisticsModel(activityStatisticsService: activityStatisticsService, dnsTrackersService: dnsTrackersService, domainsParserService: domainsParserService)
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        requestsModel?.delegate = self
        statisticsModel.chartPointsChangedDelegates.append(self)
        
        updateTheme()
        setupTableView()
        dateTypeChanged(dateType: resources.activityStatisticsType)
        addObservers()
        filterButton.isHidden = !configuration.advancedMode
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let height = tableHeaderView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        var headerFrame = tableHeaderView.frame

        if height != headerFrame.size.height {
            headerFrame.size.height = height
            tableHeaderView.frame = headerFrame
            tableView.tableHeaderView = tableHeaderView
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == showDnsContainerSegueId, let controller = segue.destination as? DnsContainerController {
            controller.logRecord = selectedRecord
        } else if segue.identifier == showMostActiveCompaniesSegueId, let controller = segue.destination as? MostActiveCompaniesController {
            controller.mostRequestedCompanies = mostRequestedCompanies
            controller.chartDateType = resources.activityStatisticsType
        }
    }
    
    // MARK: - Actions
    
    @IBAction func changePeriodTypeAction(_ sender: UIButton) {
        showChartDateTypeController()
    }
    
    @IBAction func infoAction(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            let title = String.localizedString("requests_info_alert_title")
            let message = String.localizedString("requests_info_alert_message")
            ACSSystemUtils.showSimpleAlert(for: self, withTitle: title, message: message)
        case 1:
            let title = String.localizedString("encrypted_info_alert_title")
            let message = String.localizedString("encrypted_info_alert_message")
            ACSSystemUtils.showSimpleAlert(for: self, withTitle: title, message: message)
        case 2:
            let title = String.localizedString("average_info_alert_title")
            let message = String.localizedString("average_info_alert_message")
            ACSSystemUtils.showSimpleAlert(for: self, withTitle: title, message: message)
        case 3:
            let title = String.localizedString("companies_info_alert_title")
            let message = String.localizedString("companies_info_alert_message")
            ACSSystemUtils.showSimpleAlert(for: self, withTitle: title, message: message)
        default:
            return
        }
    }
    
    @IBAction func mostActiveTapped(_ sender: UIButton) {
        performSegue(withIdentifier: showMostActiveCompaniesSegueId, sender: self)
    }
    
    @IBAction func clearActivityLogAction(_ sender: UIButton) {
        showResetAlert(sender)
    }
    
    @IBAction func changeRequestsTypeAction(_ sender: UIButton) {
        showGroupsAlert(sender)
    }
    
    // MARK: - Tableview Datasource and Delegate
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return sectionHeaderView
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        theme.setupLabel(placeHolderLabel)
        return requestsModel?.records.count == 0 ? tableFooterView : UIView()
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if requestsModel?.records.count == 0 {
            let isBigScreen = traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .regular
            return isBigScreen ? 200.0 : 150.0
        }
        return 0.01
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requestsModel?.records.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: activityTableViewCellReuseId) as? ActivityTableViewCell {
            guard let record = requestsModel?.records[indexPath.row] else { return UITableViewCell() }
            cell.advancedMode = configuration.advancedMode
            cell.domainsParser = domainsParserService.domainsParser
            cell.theme = theme
            cell.record = record
            return cell
        }
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let record = requestsModel?.records[indexPath.row] {
            selectedRecord = record
            performSegue(withIdentifier: showDnsContainerSegueId, sender: self)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        
        if offset > activityTitle.frame.maxY && !titleInNavBarIsShown {
            delegate?.showTitle()
            titleInNavBarIsShown = true
            return
        }
        
        if offset < activityTitle.frame.maxY && titleInNavBarIsShown {
            delegate?.hideTitle()
            titleInNavBarIsShown = false
        }
    }
    
    // MARK: - Private methods

    private func updateTheme(){
        tableView.reloadData()
        view.backgroundColor = theme.backgroundColor
        refreshControl?.tintColor = theme.grayTextColor
        sectionHeaderView.backgroundColor = theme.backgroundColor
        tableHeaderView.backgroundColor = theme.backgroundColor
        theme.setupLabel(recentActivityLabel)
        theme.setupTable(tableView)
        theme.setupSearchBar(searchBar)
        theme.setupLabels(themableLabels)
        theme.setupButtons(themableButtons)
        mostActiveButton.customHighlightedBackgroundColor = theme.selectedCellColor
    }
    
    private func observeAdvancedMode(){
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            self.filterButton.isHidden = !self.configuration.advancedMode
            self.tableView.reloadData()
        }
    }
    
    private func showResetAlert(_ sender: UIButton){
        let alert = UIAlertController(title: String.localizedString("reset_activity_title"), message: String.localizedString("reset_activity_message"), preferredStyle: .actionSheet)
        
        let yesAction = UIAlertAction(title: String.localizedString("common_action_yes"), style: .destructive) {[weak self] _ in
            alert.dismiss(animated: true, completion: nil)
            self?.requestsModel?.clearRecords()
        }
        
        alert.addAction(yesAction)
        
        let cancelAction = UIAlertAction(title: String.localizedString("common_action_cancel"), style: .cancel) { _ in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(cancelAction)
        
        if let presenter = alert.popoverPresentationController {
            presenter.sourceView = sender
            presenter.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showGroupsAlert(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let allRequestsAction = UIAlertAction(title: String.localizedString("all_requests_alert_action"), style: .default) {[weak self] _ in
            guard let self = self else { return }
            self.requestsModel?.displayedStatisticsType = .allRequests
            self.requestsModel?.obtainRecords(for: self.resources.activityStatisticsType)
            alert.dismiss(animated: true, completion: nil)
        }
        
        let blockedOnlyAction = UIAlertAction(title: String.localizedString("blocked_only_alert_action"), style: .default) {[weak self] _ in
            guard let self = self else { return }
            self.requestsModel?.displayedStatisticsType = .blockedRequests
            self.requestsModel?.obtainRecords(for: self.resources.activityStatisticsType)
            alert.dismiss(animated: true, completion: nil)
        }
        
        let allowedOnlyAction = UIAlertAction(title: String.localizedString("allowed_only_alert_action"), style: .default) {[weak self] _ in
            guard let self = self else { return }
            self.requestsModel?.displayedStatisticsType = .allowedRequests
            self.requestsModel?.obtainRecords(for: self.resources.activityStatisticsType)
            alert.dismiss(animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: String.localizedString("common_action_cancel"), style: .cancel) { _ in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(allRequestsAction)
        alert.addAction(blockedOnlyAction)
        alert.addAction(allowedOnlyAction)
        alert.addAction(cancelAction)
        
        if let presenter = alert.popoverPresentationController {
            presenter.sourceView = sender
            presenter.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    /**
     Presents ChartDateTypeController
     */
    private func showChartDateTypeController(){
        let storyboard = UIStoryboard(name: "MainPage", bundle: nil)
        guard let controller = storyboard.instantiateViewController(withIdentifier: "ChartDateTypeController") as? ChartDateTypeController else { return }
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = self
        controller.delegate = self
        
        present(controller, animated: true, completion: nil)
    }
    
    private func setupTableView(){
        let nib = UINib.init(nibName: "ActivityTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: activityTableViewCellReuseId)
        refreshControl?.addTarget(self, action: #selector(updateTableView(sender:)), for: .valueChanged)
    }
    
    private func keyboardWillShow() {
        DispatchQueue.main.async {[weak self] in
            let isEmpty = self?.tableView.numberOfRows(inSection: 0) == 0
            if !isEmpty {
                self?.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            }
        }
    }
    
    /**
     Adds observers to controller
     */
    private func addObservers(){
        themeToken = NotificationCenter.default.observe(name: NSNotification.Name( ConfigurationService.themeChangeNotification), object: nil, queue: .main) {[weak self] (notification) in
            self?.updateTheme()
        }
        
        keyboardShowToken = NotificationCenter.default.observe(name: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] (notification) in
            self?.keyboardWillShow()
        }
        
        advancedModeToken = configuration.observe(\.advancedMode) {[weak self] (_, _) in
            self?.observeAdvancedMode()
        }
        
        resetStatisticsToken = NotificationCenter.default.observe(name: NSNotification.resetStatistics, object: nil, queue: .main) { [weak self] (notification) in
            self?.dateTypeChanged(dateType: self?.resources.activityStatisticsType ?? .day)
        }
        
        resetSettingsToken = NotificationCenter.default.observe(name: NSNotification.resetSettings, object: nil, queue: .main) { [weak self] (notification) in
            self?.dateTypeChanged(dateType: self?.resources.activityStatisticsType ?? .day)
        }
        
        requestsModel?.recordsObserver = { [weak self] (records) in
            DispatchQueue.main.async {[weak self] in
                self?.tableView.reloadData()
            }
        }
    }
    
    @objc func updateTableView(sender: UIRefreshControl) {
        dateTypeChanged(dateType: resources.activityStatisticsType)
        statisticsModel.obtainStatistics(true) {
            DispatchQueue.main.async {[weak self] in
                self?.refreshControl?.endRefreshing()
            }
        }
    }
}

// MARK: - UISearchBarDelegate

extension ActivityViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        view.endEditing(true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        requestsModel?.searchString = searchText
    }
}

// MARK: - DnsRequestsDelegateProtocol

extension ActivityViewController: DnsRequestsDelegateProtocol {
    func requestsCleared() {
        DispatchQueue.main.async {[weak self] in
            self?.tableView.reloadData()
        }
    }
}

// MARK: - DateTypeChangedProtocol

extension ActivityViewController: DateTypeChangedProtocol {
    func dateTypeChanged(dateType: ChartDateType) {
        resources.activityStatisticsType = dateType
        changePeriodTypeButton.setTitle(dateType.getDateTypeString(), for: .normal)
        statisticsModel.chartDateTypeActivity = dateType
        
        activityModel.getCompanies(for: dateType) {[weak self] (info) in
            self?.processCompaniesInfo(info)
        }
        requestsModel?.obtainRecords(for: dateType)
    }
    
    private func processCompaniesInfo(_ companiesInfo: CompaniesInfo) {
        DispatchQueue.main.async {[weak self] in
            if !companiesInfo.mostRequested.isEmpty {
                self?.mostActiveButton.alpha = 1.0
                self?.mostActiveLabel.alpha = 1.0
                self?.mostActiveCompany.alpha = 1.0
                self?.rightArrowImageView.alpha = 1.0
                self?.mostActiveButton.isEnabled = true
                let record = companiesInfo.mostRequested[0]
                self?.mostActiveCompany.text = record.key
            } else {
                self?.mostActiveButton.alpha = 0.5
                self?.mostActiveLabel.alpha = 0.5
                self?.mostActiveCompany.alpha = 0.5
                self?.rightArrowImageView.alpha = 0.5
                self?.mostActiveButton.isEnabled = false
                self?.mostActiveCompany.text = String.localizedString("none_message")
            }
            
            self?.companiesNumberLabel.text = "\(companiesInfo.companiesNumber)"
            
            self?.mostRequestedCompanies = companiesInfo.mostRequested
            self?.companiesNumber = companiesInfo.companiesNumber
        }
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension ActivityViewController: UIViewControllerTransitioningDelegate{
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomAnimatedTransitioning()
    }
}

// MARK: - NumberOfRequestsChangedDelegate

extension ActivityViewController: NumberOfRequestsChangedDelegate {
    func numberOfRequestsChanged(requestsCount: Int, encryptedCount: Int, averageElapsed: Double) {
        updateTextForButtons(requestsCount: requestsCount, encryptedCount: encryptedCount, averageElapsed: averageElapsed)
    }
    
    /**
    Changes number of requests for all buttons
    */
    private func updateTextForButtons(requestsCount: Int, encryptedCount: Int, averageElapsed: Double){
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            
            let requestsNumberDefaults = self.resources.tempRequestsCount
            let requestsNumber = requestsCount + requestsNumberDefaults
            
            let ecnryptedNumberDefaults = self.resources.tempEncryptedRequestsCount
            let ecnryptedNumber = encryptedCount + ecnryptedNumberDefaults
            
            self.requestsNumberLabel.text = String.formatNumberByLocale(NSNumber(integerLiteral: requestsNumber))
            self.encryptedNumberLabel.text = String.formatNumberByLocale(NSNumber(integerLiteral: ecnryptedNumber))
            self.dataSavedLabel.text = String.simpleSecondsFormatter(NSNumber(floatLiteral: averageElapsed))
        }
    }
}
