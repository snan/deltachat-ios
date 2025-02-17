import UIKit
import DcCore
class EphemeralMessagesViewController: UITableViewController {

    var dcContext: DcContext
    var chatId: Int
    var currentIndex: Int = 0

    private lazy var options: [Int] = {
        return [0, Time.thirtySeconds, Time.oneMinute, Time.oneHour, Time.oneDay, Time.oneWeek, Time.fourWeeks]
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let button =  UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    private lazy var okButton: UIBarButtonItem = {
        let button =  UIBarButtonItem(title: String.localized("ok"), style: .done, target: self, action: #selector(okButtonPressed))
        return button
    }()

    private var staticCells: [UITableViewCell] {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = EphemeralMessagesViewController.getValString(val: $0)
            return cell
        })
    }

    init(dcContext: DcContext, chatId: Int) {
        self.dcContext = dcContext
        self.chatId = chatId
        super.init(style: .grouped)
        self.currentIndex = self.options.index(of: dcContext.getChatEphemeralTimer(chatId: chatId)) ?? 0
        self.title = String.localized("ephemeral_messages")
        hidesBottomBarWhenPushed = true

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = okButton
    }

    public static func getValString(val: Int) -> String {
        switch val {
        case 0:
            return String.localized("off")
        case Time.thirtySeconds:
            return String.localized("after_30_seconds")
        case Time.oneMinute:
            return String.localized("after_1_minute")
        case Time.oneHour:
            return String.localized("autodel_after_1_hour")
        case Time.oneDay:
            return String.localized("autodel_after_1_day")
        case Time.oneWeek:
            return String.localized("autodel_after_1_week")
        case Time.fourWeeks:
            return String.localized("autodel_after_4_weeks")
        default:
            return "Err"
        }
    }

    @objc private func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func okButtonPressed() {
        dcContext.setChatEphemeralTimer(chatId: chatId, duration: options[currentIndex])

        // pop two view controllers:
        // go directly back to the chatview where also the confirmation message will be shown
        navigationController?.popViewControllers(viewsToPop: 2, animated: true)
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return String.localized("ephemeral_messages_hint")
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up

        let oldSelectedCell = tableView.cellForRow(at: IndexPath.init(row: currentIndex, section: 0))
        oldSelectedCell?.accessoryType = .none

        let newSelectedCell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0))
        newSelectedCell?.accessoryType = .checkmark

        currentIndex = indexPath.row
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = staticCells[indexPath.row]
        if currentIndex == indexPath.row {
            cell.accessoryType = .checkmark
        }
        return cell
    }
}
