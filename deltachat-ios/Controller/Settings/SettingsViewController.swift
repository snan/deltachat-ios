import UIKit
import DcCore
import Intents

internal final class SettingsViewController: UITableViewController, ProgressAlertHandler {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case profile
        case showEmails
        case blockedContacts
        case notifications
        case receiptConfirmation
        case autocryptPreferences
        case sendAutocryptMessage
        case exportBackup
        case advanced
        case help
        case autodel
        case mediaQuality
        case downloadOnDemand
        case videoChat
        case connectivity
        case selectBackground
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    private let externalPathDescr = "File Sharing/Delta Chat"

    let documentInteractionController = UIDocumentInteractionController()

    private var connectivityChangedObserver: NSObjectProtocol?

    // MARK: - ProgressAlertHandler
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?

    // MARK: - cells
    private lazy var profileCell: ContactCell = {
        let cell = ContactCell(style: .default, reuseIdentifier: nil)
        let cellViewModel = ProfileViewModel(context: dcContext)
        cell.updateCell(cellViewModel: cellViewModel)
        cell.tag = CellTags.profile.rawValue
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var showEmailsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.showEmails.rawValue
        cell.textLabel?.text = String.localized("pref_show_emails")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = EmailOptionsViewController.getValString(val: dcContext.showEmails)
        return cell
    }()

    private lazy var blockedContactsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.blockedContacts.rawValue
        cell.textLabel?.text = String.localized("pref_blocked_contacts")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    func autodelSummary() -> String {
        let delDeviceAfter = dcContext.getConfigInt("delete_device_after")
        let delServerAfter = dcContext.getConfigInt("delete_server_after")
        if delDeviceAfter==0 && delServerAfter==0 {
            return String.localized("never")
        } else {
            return String.localized("on")
        }
    }

    private lazy var autodelCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.autodel.rawValue
        cell.textLabel?.text = String.localized("delete_old_messages")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = autodelSummary()
        return cell
    }()

    private lazy var mediaQualityCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.mediaQuality.rawValue
        cell.textLabel?.text = String.localized("pref_outgoing_media_quality")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = MediaQualityViewController.getValString(val: dcContext.getConfigInt("media_quality"))
        return cell
    }()

    private lazy var downloadOnDemandCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.downloadOnDemand.rawValue
        cell.textLabel?.text = String.localized("auto_download_messages")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = DownloadOnDemandViewController.getValString(val: dcContext.getConfigInt("download_limit"))
        return cell
    }()

    private lazy var videoChatInstanceCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.videoChat.rawValue
        cell.textLabel?.text = String.localized("videochat_instance")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var notificationSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = !UserDefaults.standard.bool(forKey: "notifications_disabled")
        switchControl.addTarget(self, action: #selector(handleNotificationToggle(_:)), for: .valueChanged)
        return switchControl
    }()

    private lazy var notificationCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.notifications.rawValue
        cell.textLabel?.text = String.localized("pref_notifications")
        cell.accessoryView = notificationSwitch
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var receiptConfirmationSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = dcContext.mdnsEnabled
        switchControl.addTarget(self, action: #selector(handleReceiptConfirmationToggle(_:)), for: .valueChanged)
        return switchControl
    }()

    private lazy var receiptConfirmationCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.receiptConfirmation.rawValue
        cell.textLabel?.text = String.localized("pref_read_receipts")
        cell.accessoryView = receiptConfirmationSwitch
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var autocryptSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = dcContext.e2eeEnabled
        switchControl.addTarget(self, action: #selector(handleAutocryptPreferencesToggle(_:)), for: .valueChanged)
        return switchControl
    }()

    private lazy var autocryptPreferencesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.autocryptPreferences.rawValue
        cell.textLabel?.text = String.localized("autocrypt_prefer_e2ee")
        cell.accessoryView = autocryptSwitch
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var sendAutocryptMessageCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.sendAutocryptMessage.rawValue
        cell.actionTitle = String.localized("autocrypt_send_asm_title")
        return cell
    }()

    private lazy var exportBackupCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.exportBackup.rawValue
        cell.actionTitle = String.localized("export_backup_desktop")
        return cell
    }()

    private lazy var advancedCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.advanced.rawValue
        cell.actionTitle = String.localized("menu_advanced")
        return cell
    }()

    private lazy var helpCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.help.rawValue
        cell.actionTitle = String.localized("menu_help")
        return cell
    }()

    private lazy var connectivityCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.connectivity.rawValue
        cell.textLabel?.text = String.localized("connectivity")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var selectBackgroundCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.tag = CellTags.selectBackground.rawValue
        cell.textLabel?.text = String.localized("pref_background")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        var appNameAndVersion = "Delta Chat"
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appNameAndVersion += " v" + appVersion
        }
        let profileSection = SectionConfigs(
            headerTitle: String.localized("pref_profile_info_headline"),
            footerTitle: nil,
            cells: [profileCell]
        )
        let preferencesSection = SectionConfigs(
            headerTitle: String.localized("pref_chats_and_media"),
            footerTitle: String.localized("pref_read_receipts_explain"),
            cells: [showEmailsCell, blockedContactsCell, mediaQualityCell, downloadOnDemandCell,
                    autodelCell, videoChatInstanceCell, notificationCell, receiptConfirmationCell]
        )
        let appearanceSection = SectionConfigs(
            headerTitle: String.localized("pref_appearance"),
            footerTitle: nil,
            cells: [selectBackgroundCell]
        )
        let autocryptSection = SectionConfigs(
            headerTitle: String.localized("autocrypt"),
            footerTitle: String.localized("autocrypt_explain"),
            cells: [autocryptPreferencesCell, sendAutocryptMessageCell]
        )
        let backupSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("pref_backup_explain"),
            cells: [advancedCell, exportBackupCell])
        let helpSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: appNameAndVersion,
            cells: [connectivityCell, helpCell]
        )

        return [profileSection, preferencesSection, appearanceSection, autocryptSection, backupSection, helpSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .grouped)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_settings")
        documentInteractionController.delegate = self as? UIDocumentInteractionControllerDelegate
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // set connectivity changed observer before we acutally init `connectivityCell.detailTextLabel` in `updateCells()`,
        // otherwise, we may miss events and the label is not correct.
        connectivityChangedObserver = NotificationCenter.default.addObserver(forName: dcNotificationConnectivityChanged,
                                                                             object: nil,
                                                                             queue: nil) { [weak self] _ in
            guard let self = self else { return }
            self.connectivityCell.detailTextLabel?.text = DcUtils.getConnectivityString(dcContext: self.dcContext,
                                                                                        connectedString: String.localized("connectivity_connected"))
        }

        updateCells()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addProgressAlertListener(dcAccounts: dcAccounts, progressName: dcNotificationImexProgress) { [weak self] in
            guard let self = self else { return }

            self.progressAlert?.dismiss(animated: true) {
                let alert = UIAlertController(
                    title: String.localized("backup_successful"),
                    message: String.localizedStringWithFormat(String.localized("backup_successful_explain_ios"), "\(String.localized("Files")) ➔ Delta Chat"),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        appDelegate.reloadDcContext()
                    }
                }))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let nc = NotificationCenter.default
        if let backupProgressObserver = self.progressObserver {
            nc.removeObserver(backupProgressObserver)
        }
        if let connectivityChangedObserver = self.connectivityChangedObserver {
            NotificationCenter.default.removeObserver(connectivityChangedObserver)
        }
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource


    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row == 0 {
            return ContactCell.cellHeight
        } else {
            return UITableView.automaticDimension
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else {
            safe_fatalError()
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .profile: showEditSettingsController()
        case .showEmails: showClassicMail()
        case .blockedContacts: showBlockedContacts()
        case .autodel: showAutodelOptions()
        case .mediaQuality: showMediaQuality()
        case .downloadOnDemand: showDownloadOnDemand()
        case .videoChat: showVideoChatInstance()
        case .notifications: break
        case .receiptConfirmation: break
        case .autocryptPreferences: break
        case .sendAutocryptMessage: sendAutocryptSetupMessage()
        case .exportBackup: createBackup()
        case .advanced: showAdvancedDialog()
        case .help: showHelp()
        case .connectivity: showConnectivity()
        case .selectBackground: selectBackground()
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    // MARK: - actions

    private func createBackup() {
        let alert = UIAlertController(title: String.localized("pref_backup_export_explain"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("pref_backup_export_start_button"), style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
            self.startImex(what: DC_IMEX_EXPORT_BACKUP)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func handleNotificationToggle(_ sender: UISwitch) {
        UserDefaults.standard.set(!sender.isOn, forKey: "notifications_disabled")
        if sender.isOn {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.registerForNotifications()
            }
        } else {
            NotificationManager.removeAllNotifications()
        }
        UserDefaults.standard.synchronize()
        NotificationManager.updateApplicationIconBadge(dcContext: dcContext, reset: !sender.isOn)
    }

    @objc private func handleReceiptConfirmationToggle(_ sender: UISwitch) {
        dcContext.mdnsEnabled = sender.isOn
    }

    @objc private func handleAutocryptPreferencesToggle(_ sender: UISwitch) {
        dcContext.e2eeEnabled = sender.isOn
    }

    private func sendAutocryptSetupMessage() {
        let askAlert = UIAlertController(title: String.localized("autocrypt_send_asm_explain_before"), message: nil, preferredStyle: .safeActionSheet)
        askAlert.addAction(UIAlertAction(title: String.localized("autocrypt_send_asm_title"), style: .default, handler: { _ in
                let sc = self.dcContext.initiateKeyTransfer()
                guard var sc = sc else {
                    return
                }
                if sc.count == 44 {
                    // format setup code to the typical 3 x 3 numbers
                    sc = sc.substring(0, 4) + "  -  " + sc.substring(5, 9) + "  -  " + sc.substring(10, 14) + "  -\n\n" +
                        sc.substring(15, 19) + "  -  " + sc.substring(20, 24) + "  -  " + sc.substring(25, 29) + "  -\n\n" +
                        sc.substring(30, 34) + "  -  " + sc.substring(35, 39) + "  -  " + sc.substring(40, 44)
                }

                let text = String.localizedStringWithFormat(String.localized("autocrypt_send_asm_explain_after"), sc)
                let showAlert = UIAlertController(title: text, message: nil, preferredStyle: .alert)
                showAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.present(showAlert, animated: true, completion: nil)
        }))
        askAlert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(askAlert, animated: true, completion: nil)
    }

    private func showLogViewController() {
        let controller = LogViewController(dcContext: dcContext)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showExperimentalDialog() {
        let alert = UIAlertController(title: String.localized("pref_experimental_features"), message: nil, preferredStyle: .safeActionSheet)

        let broadcastLists = UserDefaults.standard.bool(forKey: "broadcast_lists")
        alert.addAction(UIAlertAction(title: (broadcastLists ? "✔︎ " : "") + String.localized("broadcast_lists"),
                                      style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            UserDefaults.standard.set(!broadcastLists, forKey: "broadcast_lists")
            if !broadcastLists {
                let alert = UIAlertController(title: "Thanks for trying out the experimental feature 🧪 \"Broadcast Lists\"!",
                                              message: "You can now create new \"Broadcast Lists\" from the \"New Chat\" dialog\n\n"
                                                + "In case you are using more than one device, broadcast lists are currently not synced between them\n\n"
                                                + "If you want to quit the experimental feature, you can disable it at \"Settings / Advanced\".",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.navigationController?.present(alert, animated: true, completion: nil)
            }
        }))

        let locationStreaming = UserDefaults.standard.bool(forKey: "location_streaming")
        let title = (locationStreaming ? "✔︎ " : "") + String.localized("pref_on_demand_location_streaming")
        alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            UserDefaults.standard.set(!locationStreaming, forKey: "location_streaming")
            if !locationStreaming {
                let alert = UIAlertController(title: "Thanks for trying out the experimental feature 🧪 \"Location streaming\"",
                                              message: "You will find a corresponding option in the attach menu (the paper clip) of each chat now.\n\n"
                                                + "If you want to quit the experimental feature, you can disable it at \"Settings / Advanced\".",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.navigationController?.present(alert, animated: true, completion: nil)
            } else if self.dcContext.isSendingLocationsToChat(chatId: 0) {
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                    return
                }
                appDelegate.locationManager.disableLocationStreamingInAllChats()
            }
        }))

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func showAdvancedDialog() {
        let alert = UIAlertController(title: String.localized("menu_advanced"), message: nil, preferredStyle: .safeActionSheet)

        alert.addAction(UIAlertAction(title: String.localized("pref_managekeys_export_secret_keys"), style: .default, handler: { _ in
            let msg = String.localizedStringWithFormat(String.localized("pref_managekeys_export_explain"), self.externalPathDescr)
            let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                self.startImex(what: DC_IMEX_EXPORT_SELF_KEYS)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: String.localized("pref_managekeys_import_secret_keys"), style: .default, handler: { _ in
            let msg = String.localizedStringWithFormat(String.localized("pref_managekeys_import_explain"), self.externalPathDescr)
            let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                self.startImex(what: DC_IMEX_IMPORT_SELF_KEYS)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: String.localized("pref_experimental_features"), style: .default, handler: { [weak self] _ in
            self?.showExperimentalDialog()
        }))

        let logAction = UIAlertAction(title: String.localized("pref_view_log"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.showLogViewController()
        })
        alert.addAction(logAction)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func presentError(message: String) {
        let error = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        error.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel))
        present(error, animated: true)
    }

    private func startImex(what: Int32, passphrase: String? = nil) {
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            showProgressAlert(title: String.localized("imex_progress_title_desktop"), dcContext: dcContext)
            DispatchQueue.main.async {
                self.dcAccounts.stopIo()
                self.dcContext.imex(what: what, directory: documents[0], passphrase: passphrase)
            }
        } else {
            logger.error("document directory not found")
        }
    }

    // MARK: - updates
    private func updateCells() {
        profileCell.updateCell(cellViewModel: ProfileViewModel(context: dcContext))
        showEmailsCell.detailTextLabel?.text = EmailOptionsViewController.getValString(val: dcContext.showEmails)
        mediaQualityCell.detailTextLabel?.text = MediaQualityViewController.getValString(val: dcContext.getConfigInt("media_quality"))
        downloadOnDemandCell.detailTextLabel?.text = DownloadOnDemandViewController.getValString(
            val: dcContext.getConfigInt("download_limit"))
        videoChatInstanceCell.detailTextLabel?.text = VideoChatInstanceViewController.getValString(val: dcContext.getConfig("webrtc_instance") ?? "")
        autodelCell.detailTextLabel?.text = autodelSummary()
        connectivityCell.detailTextLabel?.text = DcUtils.getConnectivityString(dcContext: dcContext,
                                                                               connectedString: String.localized("connectivity_connected"))
    }

    // MARK: - coordinator
    private func showEditSettingsController() {
        let editController = SelfProfileViewController(dcAccounts: dcAccounts)
        navigationController?.pushViewController(editController, animated: true)
    }

    private func showClassicMail() {
        let settingsClassicViewController = EmailOptionsViewController(dcContext: dcContext)
        navigationController?.pushViewController(settingsClassicViewController, animated: true)
    }

    private func  showMediaQuality() {
        let mediaQualityController = MediaQualityViewController(dcContext: dcContext)
        navigationController?.pushViewController(mediaQualityController, animated: true)
    }

    private func showDownloadOnDemand() {
        let downloadOnDemandViewController = DownloadOnDemandViewController(dcContext: dcContext)
        navigationController?.pushViewController(downloadOnDemandViewController, animated: true)
    }

    private func showVideoChatInstance() {
        let videoInstanceController = VideoChatInstanceViewController(dcContext: dcContext)
        navigationController?.pushViewController(videoInstanceController, animated: true)
    }

    private func showBlockedContacts() {
        let blockedContactsController = BlockedContactsViewController(dcContext: dcContext)
        navigationController?.pushViewController(blockedContactsController, animated: true)
    }

    private func showAutodelOptions() {
        let settingsAutodelOverviewController = AutodelOverviewViewController(dcContext: dcContext)
        navigationController?.pushViewController(settingsAutodelOverviewController, animated: true)
    }

    private func showHelp() {
        navigationController?.pushViewController(HelpViewController(dcContext: dcContext), animated: true)
    }

    private func showConnectivity() {
        navigationController?.pushViewController(ConnectivityViewController(dcContext: dcContext), animated: true)
    }

    private func selectBackground() {
        navigationController?.pushViewController(BackgroundOptionsViewController(dcContext: dcContext), animated: true)
    }

}
