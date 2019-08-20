//
//  MasterViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.12.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import os.log
import UIKit

public protocol ArchiveViewControllerDelegate: AnyObject {
    func update(_ contentType: ContentType)
}

class ArchiveViewController: UIViewController, UITableViewDelegate, Logging {

    // MARK: - Properties
    @IBOutlet var tableView: UITableView!

    let searchController = UISearchController(searchResultsController: nil)
    var selectedDocument: IndexPath?

    var currentDocuments = Set<Document>()
    var currentSections = [TableSection<String, Document>]()

    // Table view cells are reused and should be dequeued using a cell identifier.
    private let cellIdentifier = "DocumentTableViewCell"
    private let allLocal = NSLocalizedString("all", comment: "")
    private let placeholderViewController = PlaceholderViewController(text: NSLocalizedString("archive_tab.background_placeholder", comment: "Placeholder that is shown, when no document can be found."))
    private var editViewController: DocumentViewController?

    private let notificationFeedback = UINotificationFeedbackGenerator()

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)

        // setup data delegate
        DocumentService.documentsQuery.masterViewControllerDelegate = self

        // Setup the Search Controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Documents"
        navigationItem.searchController = searchController
        definesPresentationContext = true

        // Setup the Scope Bar
        searchController.searchBar.scopeButtonTitles = [allLocal, "2018", "2017", "2016"]
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = NSLocalizedString("search-documents", comment: "UISearchBar placeholder")

        // setup background view controller
        tableView.backgroundView = Bundle.main.loadNibNamed("LoadingBackgroundView", owner: nil, options: nil)?.first as? UIView
        tableView.separatorStyle = .none

        // update the view controller, even if the documents query ends before the view did load
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.updateDocuments(changed: Set<Document>())
        }

//        #if targetEnvironment(simulator)
//        // create simulator data set
//        if let fileURL = Bundle.main.url(forResource: NSLocalizedString("test_resource_filename", comment: "Simulator test data set"), withExtension: "pdf") {
//
//            DocumentService.archive.add(from: fileURL, size: 1427000, downloadStatus: .local, status: .untagged)
//            DocumentService.archive.add(from: URL(fileURLWithPath: NSLocalizedString("test_file1", comment: "Simulator test data set")), size: 1427000, downloadStatus: .local, status: .tagged)
//            DocumentService.archive.add(from: URL(fileURLWithPath: NSLocalizedString("test_file2", comment: "Simulator test data set")), size: 232000, downloadStatus: .iCloudDrive, status: .tagged)
//            DocumentService.archive.add(from: fileURL, size: 500000, downloadStatus: .local, status: .tagged)
//            DocumentService.archive.add(from: URL(fileURLWithPath: NSLocalizedString("test_file3", comment: "Simulator test data set")), size: 764500, downloadStatus: .iCloudDrive, status: .tagged)
//        } else {
//            assertionFailure("Could not load resurces")
//        }
//        #endif

        updateDocuments(changed: DocumentService.archive.filterContentForSearchText(""))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let splitViewController = splitViewController,
            splitViewController.isCollapsed {
            if let selectionIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectionIndexPath, animated: animated)
            }
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetails",
            let indexPath = selectedDocument,
            let navigationController = segue.destination as? UINavigationController,
            let controller = navigationController.topViewController as? DetailViewController,
            let document = getDocument(from: indexPath) {

            // "shouldPerformSegue" performs the document download
            if document.downloadStatus != .local {
                fatalError("Segue peparation, but the document (status: \(String(describing: document.downloadStatus))) could not be found locally!")
            }

            controller.detailDocument = document

            // send haptic feedback
            notificationFeedback.prepare()
            notificationFeedback.notificationOccurred(.success)

            // avoid inverted colors in tags by deselecting the cell
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }

    // MARK: - internal helper functions

    private func getDocument(from indexPath: IndexPath) -> Document? {
        let tableSection = currentSections[indexPath.section]
        return tableSection.rowItems[indexPath.row]
    }

    private func getIndexPath(of document: Document, in sections: [TableSection<String, Document>]) -> IndexPath? {
        if let sectionIndex = sections.firstIndex(where: { $0.sectionItem == document.folder }),
            let rowIndex = sections[sectionIndex].rowItems.firstIndex(where: { $0 == document }) {
            return IndexPath(row: rowIndex, section: sectionIndex)
        } else {
            return nil
        }
    }

    private func diff(_ lhs: [TableSection<String, Document>], with rhs: [TableSection<String, Document>]) -> IndexSet {

        // get baseline section names
        let rhsNames = Set(rhs.map { $0.sectionItem })

        // compare the baseline with the other sections
        var indizies = IndexSet()
        for (index, section) in lhs.enumerated() where !rhsNames.contains(section.sectionItem) {
            indizies.insert(index)
        }
        return indizies
    }

    private func diff(_ lhs: Set<Document>, with rhs: Set<Document>, in sections: [TableSection<String, Document>]) -> [IndexPath] {

        var indexPaths = [IndexPath]()
        for document in lhs.subtracting(rhs) {
            guard let indexPath = getIndexPath(of: document, in: sections) else { os_log("No index path found for document: %@", log: ArchiveViewController.log, type: .error, document.filename); continue }
            indexPaths.append(indexPath)
        }
        return indexPaths
    }

    func updateDocuments(changed changedDocuments: Set<Document>) {

        // setup background view controller
        if DocumentService.archive.get(scope: .all, searchterms: [], status: .tagged).isEmpty {
            tableView.backgroundView = placeholderViewController.view
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }

        /*
         Filter the documents
         */
        // setup search toolbar
        self.searchController.searchBar.scopeButtonTitles = [allLocal] + Array(DocumentService.archive.years.sorted().reversed().prefix(3))
        #if targetEnvironment(simulator)
        self.searchController.searchBar.scopeButtonTitles = [allLocal, "2018", "2017", "2016"]
        #endif

        // update the filtered documents
        let searchBar = self.searchController.searchBar
        let searchBarText = searchBar.text ?? ""

        // update the table view data
        var scope: String
        if let scopeButtonTitles = searchBar.scopeButtonTitles {
            scope = scopeButtonTitles[searchBar.selectedScopeButtonIndex]
        } else {
            scope = self.allLocal
        }
        let newDocuments = DocumentService.archive.filterContentForSearchText(searchBarText, scope: scope)

        // sort documents by Date (descending) and Name (ascending)
        let sortedDocuments: [Document] = Array(newDocuments).sorted().reversed()

        // create table sections
        let newSections: [TableSection<String, Document>] = TableSection.group(rowItems: sortedDocuments) { (document) in
            let calender = Calendar.current
            guard let date = document.date else { fatalError("Document has no date.") }
            return String(calender.component(.year, from: date))
        }.reversed()

        /*
         Update the view aka. create animations.
         */
        let animation = UITableView.RowAnimation.fade
        tableView.performBatchUpdates({

            // save the old documents
            let oldDocuments = currentDocuments
            let oldSections = currentSections

            // deleted sections & documents
            tableView.deleteRows(at: diff(oldDocuments, with: newDocuments, in: oldSections), with: animation)
            tableView.deleteSections(diff(oldSections, with: newSections), with: animation)

            // new sections & documents
            tableView.insertRows(at: diff(newDocuments, with: oldDocuments, in: newSections), with: animation)
            tableView.insertSections(diff(newSections, with: oldSections), with: animation)

            // Save the results
            self.currentSections = newSections
            self.currentDocuments = newDocuments
        }, completion: {success in
            if success {

                // update the download status of all changed documents
                for changedDocument in changedDocuments {
                    if let indexPath = self.getIndexPath(of: changedDocument, in: self.currentSections),
                        let cell = self.tableView.cellForRow(at: indexPath) as? DocumentTableViewCell {

                        cell.updateDownloadStatus(for: changedDocument)
                    }
                }

                // perform the segue, if the document was downloaded successfully
                if let indexPath = self.tableView.indexPathForSelectedRow,
                    let document = self.getDocument(from: indexPath),
                    document.downloadStatus == .local {

                    self.performSegue(withIdentifier: "showDetails", sender: self)
                }
            }
        })
    }
}

// MARK: -
extension ArchiveViewController: UITableViewDataSource {

    // MARK: required stubs
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentSections[section].rowItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // get the desired cell
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? DocumentTableViewCell else {
            fatalError("The dequeued cell is not an instance of TableViewCell.")
        }

        // update the cell document and content
        guard let document = getDocument(from: indexPath) else {
            fatalError("No document found during table cell update.")
        }
        cell.document = document
        return cell
    }

    // MARK: optional stubs

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(84)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return currentSections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return currentSections[section].sectionItem
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let document = getDocument(from: indexPath) else { return }
        os_log("Selected Document: %@", log: ArchiveViewController.log, type: .debug, document.filename)
        notificationFeedback.prepare()

        // download document if it is not already available
        switch document.downloadStatus {
        case .local:
            notificationFeedback.notificationOccurred(.success)
            selectedDocument = indexPath
            performSegue(withIdentifier: "showDetails", sender: self)
        case .downloading:
            os_log("Downloading currently ...", log: ArchiveViewController.log, type: .debug)
        case .iCloudDrive:
            notificationFeedback.notificationOccurred(.success)
            os_log("Start download ...", log: ArchiveViewController.log, type: .debug)
            document.download()
            selectedDocument = tableView.indexPathForSelectedRow
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        var actions = [UIContextualAction]()
        guard let document = self.getDocument(from: indexPath) else { return nil }

        if document.downloadStatus != .local {
            // action: download
            let download = UIContextualAction(style: .destructive, title: NSLocalizedString("download", comment: "")) { _, _, _  in
                guard document.downloadStatus != .local else {
                    assertionFailure("Try to download local document. This should not happen!")
                    return
                }
                document.download()
            }
            download.backgroundColor = .paLightGray

            // this might be used on iOS 13
//            actions.append(download)
        } else {
            // action: edit
            let edit = UIContextualAction(style: .destructive, title: NSLocalizedString("edit", comment: "")) { _, _, _  in
                self.edit(document)
            }
            edit.backgroundColor = .paLightGray
            // this might be used on iOS 13
//            actions.append(edit)
        }

        // action: delete
        let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("delete", comment: "")) { _, _, _  in
            self.delete(document)
        }
        delete.backgroundColor = .paDelete
        actions.append(delete)

        return UISwipeActionsConfiguration(actions: actions.reversed())
    }

    // MARK: optical changes
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let view = view as? UITableViewHeaderFooterView else { return }

        // change colors
        view.textLabel?.textColor = .paDarkRed
        view.backgroundView?.backgroundColor = .paWhite
    }

    private func delete(_ document: Document) {

        let path: URL
        if document.downloadStatus == .local {
            path = document.path
        } else {
            let iCloudFilename = ".\(document.filename).icloud"
            path = document.path.deletingLastPathComponent().appendingPathComponent(iCloudFilename)
        }

        do {
            try FileManager.default.removeItem(at: path)

            let removedDocument = Set([document])
            DocumentService.archive.remove(removedDocument)
            self.updateDocuments(changed: removedDocument)
        } catch {
            let alert = UIAlertController(title: NSLocalizedString("ArchiveViewController.delete_failed.title", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button confirmation label"), style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func edit(_ document: Document) {
        DocumentService.archive.remove(Set([document]))
        selectedDocument = nil

        guard let controller = DocumentViewController(document: document) else { fatalError("Could not create DocumentViewController!") }
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissEdit))
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveEdit))
        editViewController = controller

        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.view.backgroundColor = .white
        present(navigationController, animated: true) {
            self.updateDocuments(changed: [])
        }
    }

    @objc
    private func dismissEdit() {
        if let document = editViewController?.document {
            print(document)
            // TODO: add document to the archive again
//            DocumentService.archive.add(document)
        }

        editViewController?.navigationController?.dismiss(animated: true, completion: nil)
    }

    @objc
    private func saveEdit() {

        Log.info("Save edited document in archive.")

        guard let document = editViewController?.document else { fatalError("Could not get document from edit DocumentViewController.") }
        guard let path = StorageHelper.Paths.archivePath else {
            assertionFailure("Could not find a iCloud Drive url.")
            present(StorageHelper.Paths.iCloudDriveAlertController, animated: true, completion: nil)
            return
        }

        notificationFeedback.prepare()
        do {
            try document.rename(archivePath: path, slugify: true)

            // send haptic feedback
            notificationFeedback.notificationOccurred(.success)
            editViewController?.navigationController?.dismiss(animated: true, completion: nil)

        } catch let error as LocalizedError {
            os_log("Error occurred while renaming Document: %@", log: DocumentHandleViewController.log, type: .error, error.localizedDescription)

            // OK button will be created by the convenience initializer
            let alertController = UIAlertController(error, preferredStyle: .alert)
            present(alertController, animated: true, completion: nil)
            notificationFeedback.notificationOccurred(.error)
        } catch {
            os_log("Error occurred while renaming Document: %@", log: DocumentHandleViewController.log, type: .error, error.localizedDescription)
            let alertController = UIAlertController(title: NSLocalizedString("error_message_fallback", comment: "Fallback when no localized error was found."), message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button confirmation label"), style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            notificationFeedback.notificationOccurred(.error)
        }
    }
}

// MARK: -
extension ArchiveViewController: ArchiveViewControllerDelegate {
    func update(_ contentType: ContentType) {
        switch contentType {
        case .archivedDocuments(let changedDocuments):
            // these documents must be updated on the main thread, since it changes ui elements
            DispatchQueue.main.async {
                self.updateDocuments(changed: changedDocuments)
            }
        default:
            os_log("Type does not match.", log: ArchiveViewController.log, type: .debug)
        }
    }
}

extension ArchiveViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateDocuments(changed: [])
    }
}

extension ArchiveViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        updateDocuments(changed: [])
    }
}
