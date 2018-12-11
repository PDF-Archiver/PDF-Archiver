/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import ArchiveLib
import os.log
import UIKit

class MasterViewController: UIViewController, UITableViewDelegate, Logging {

    // MARK: - Properties
    @IBOutlet var tableView: UITableView!

    var detailViewController: DetailViewController?
    var archive = Archive()
    var documentsQuery = DocumentsQuery()
    let searchController = UISearchController(searchResultsController: nil)
    var selectedDocument: IndexPath?

    var currentDocuments = Set<Document>()
    var currentSections = [TableSection<String, Document>]()

    // Table view cells are reused and should be dequeued using a cell identifier.
    private let cellIdentifier = "DocumentTableViewCell"
    private let allLocal = NSLocalizedString("all", comment: "")

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)

        // setup data delegate
        // TODO: update this delegate
        documentsQuery.delegate = archive
        archive.archiveDelegate = self

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

        if let splitViewController = splitViewController {
            let controllers = splitViewController.viewControllers
            // swiftlint:disable force_cast
            detailViewController = (controllers[controllers.count - 1] as! UINavigationController).topViewController as? DetailViewController
            // swiftlint:enable force_cast
        }

        // setup background view controller
        tableView.backgroundView = Bundle.main.loadNibNamed("LoadingBackgroundView", owner: nil, options: nil)?.first as? UIView
        tableView.separatorStyle = .none
    }

    override func viewWillAppear(_ animated: Bool) {
        if let splitViewController = splitViewController,
            splitViewController.isCollapsed {
            if let selectionIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectionIndexPath, animated: animated)
            }
        }
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true

            // increment the AppStoreReview counter
            AppStoreReviewRequest.shared.incrementCount()

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
            guard let indexPath = getIndexPath(of: document, in: sections) else { print("WARNING!!!!!!!!!!!!\n\n"); continue }
            indexPaths.append(indexPath)
        }
        return indexPaths
    }

    func updateDocuments(changed changedDocuments: Set<Document>) {

        // save the old documents
        let oldDocuments = currentDocuments
        let oldSections = currentSections

        // setup background view controller
        if archive.get(scope: .all, searchterms: [], status: .tagged).isEmpty {
            tableView.backgroundView = Bundle.main.loadNibNamed("EmptyBackgroundView", owner: nil, options: nil)?.first as? UIView
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }

        /*
         Filter the documents
         */
        // setup search toolbar
        self.searchController.searchBar.scopeButtonTitles = [allLocal] + Array(archive.years.sorted().reversed().prefix(3))

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
        let newDocuments = self.archive.filterContentForSearchText(searchBarText, scope: scope)

        // sort documents by Date (descending) and Name (ascending)
        let sortedDocuments: [Document] = Array(newDocuments).sorted().reversed()

        // create table sections
        let newSections: [TableSection<String, Document>] = TableSection.group(rowItems: sortedDocuments) { (document) in
            let calender = Calendar.current
            return String(calender.component(.year, from: document.date))
        }.reversed()

        /*
         Update the view aka. create animations.
         */
        let animation = UITableView.RowAnimation.fade
        tableView.performBatchUpdates({

            // new sections & documents
            tableView.insertSections(diff(newSections, with: oldSections), with: animation)
            tableView.insertRows(at: diff(newDocuments, with: oldDocuments, in: newSections), with: animation)

            // deleted sections & documents
            tableView.deleteSections(diff(oldSections, with: newSections), with: animation)
            tableView.deleteRows(at: diff(oldDocuments, with: newDocuments, in: currentSections), with: animation)

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
extension MasterViewController: UITableViewDataSource {

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
    func numberOfSections(in tableView: UITableView) -> Int {
        return currentSections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return currentSections[section].sectionItem
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let document = getDocument(from: indexPath),
            let downloadStatus = document.downloadStatus else { return }
        os_log("Selected Document: %@", log: log, type: .debug, document.filename)

        // download document if it is not already available
        switch downloadStatus {
        case .local:
            selectedDocument = indexPath
            performSegue(withIdentifier: "showDetails", sender: self)
        case .downloading:
            print("Downloading currently ...")
        case .iCloudDrive:
            print("Start download ...")
            document.download()
            selectedDocument = tableView.indexPathForSelectedRow
        }
    }

    // MARK: optical changes
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let view = view as? UITableViewHeaderFooterView else { return }

        // change colors
        view.textLabel?.textColor = UIColor(named: "MainTextColor")
        view.backgroundView?.backgroundColor = UIColor(named: "MainBackgroundColor")
    }
}

// MARK: -
extension MasterViewController: ArchiveDelegate {
    func update(_ contentType: ContentType) {
        switch contentType {
        case .archivedDocuments(let changedDocuments):
            DispatchQueue.main.async {
                self.updateDocuments(changed: changedDocuments)
            }
        default:
            os_log("Type does not match.", log: self.log, type: .debug)
        }
    }
}

extension MasterViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateDocuments(changed: [])
    }
}

extension MasterViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        updateDocuments(changed: [])
    }
}
