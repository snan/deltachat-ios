import UIKit
import DcCore

class DocumentGalleryController: UIViewController {

    private let fileMessageIds: [Int]

    private lazy var tableViews: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.register(FileTableViewCell.self, forCellReuseIdentifier: FileTableViewCell.reuseIdentifier)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 60
        return table
    }()

    init(fileMessageIds: [Int]) {
        self.fileMessageIds = fileMessageIds
        super.init(nibName: nil, bundle: nil)
        self.title = String.localized("documents")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }

    // MARK: - layout
    private func setupSubviews() {
        view.addSubview(tableViews)
        tableViews.translatesAutoresizingMaskIntoConstraints = false
        tableViews.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        tableViews.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableViews.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        tableViews.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension DocumentGalleryController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileMessageIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: FileTableViewCell.reuseIdentifier, for: indexPath) as? FileTableViewCell else {
            return UITableViewCell()
        }
        let msg = DcMsg(id: fileMessageIds[indexPath.row])
        cell.update(msg: msg)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let msgId = fileMessageIds[indexPath.row]
        showPreview(msgId: msgId)
        tableView.deselectRow(at: indexPath, animated: false)
    }
}

// MARK: - coordinator
extension DocumentGalleryController {
    func showPreview(msgId: Int) {
        guard let index = fileMessageIds.index(of: msgId) else {
            return
        }

        let mediaUrls = fileMessageIds.compactMap {
            return DcMsg(id: $0).fileURL
        }
        let previewController = PreviewController(currentIndex: index, urls: mediaUrls)
        present(previewController, animated: true, completion: nil)
    }
}
