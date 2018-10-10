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

import os.log
import UIKit

class MasterViewController: UIViewController, UITableViewDelegate, Logging {

    // MARK: - Properties
    @IBOutlet var tableView: UITableView!

    var detailViewController: DetailViewController?
    var archive = Archive()
    var documentsQuery = DocumentsQuery()
    let searchController = UISearchController(searchResultsController: nil)

    // Table view cells are reused and should be dequeued using a cell identifier.
    private let cellIdentifier = "DocumentTableViewCell"
    private let allLocal = NSLocalizedString("all", comment: "")

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)

        // setup data delegate
        documentsQuery.delegate = self

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
        tableView.backgroundView = Bundle.main.loadNibNamed("EmptyBackgroundView", owner: nil, options: nil)?.first as? UIView
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
            let indexPath = tableView.indexPathForSelectedRow,
            let navigationController = segue.destination as? UINavigationController,
            let controller = navigationController.topViewController as? DetailViewController,
            let document = getSelectedDocument(from: indexPath) {

            // "shouldPerformSegue" performs the document download
            if document.downloadStatus != .local {
                fatalError("Segue peparation, but the document (status: \(document.downloadStatus)) could not be found locally!")
            }

            controller.detailDocument = document
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true

            // increment the AppStoreReview counter
            AppStoreReviewRequest.shared.incrementCount()
        }
    }

    // MARK: - Private instance methods
    private func getSelectedDocument(from indexPath: IndexPath) -> Document? {
        let tableSection = archive.sections[indexPath.section]
        return tableSection.rowItems[indexPath.row]
    }
}

// MARK: - Delegates
extension MasterViewController: DocumentsQueryDelegate {
    func documentsQueryResultsDidChangeWithResults(documents: [Document], tags: Set<Tag>) {
        archive.setAllDocuments(documents.sorted().reversed())
        archive.availableTags = tags

        // setup background view controller
        if documents.isEmpty {
            tableView.backgroundView = Bundle.main.loadNibNamed("EmptyBackgroundView", owner: nil, options: nil)?.first as? UIView
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }

        // setup search toolbar
        searchController.searchBar.scopeButtonTitles = [allLocal] + archive.years

        // update the filtered documents
        let searchBar = searchController.searchBar
        let searchBarText = searchBar.text ?? ""
        if let scopeButtonTitles = searchBar.scopeButtonTitles {
            archive.filterContentForSearchText(searchBarText, scope: scopeButtonTitles[searchBar.selectedScopeButtonIndex])
        } else {
            archive.filterContentForSearchText(searchBarText, scope: allLocal)
        }

        // reload the table view data
        tableView.reloadData()
    }
}

extension MasterViewController: UITableViewDataSource {

    // MARK: - required stubs
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        let tableSection = archive.sections[section]
        return tableSection.rowItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // get the desired cell
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? DocumentTableViewCell else {
            fatalError("The dequeued cell is not an instance of TableViewCell.")
        }

        // update the cell document and content
        guard let document = getSelectedDocument(from: indexPath) else {
            fatalError("No document found during table cell update.")
        }
        cell.document = document
        cell.layoutSubviews()
        return cell
    }

    // MARK: - optional stubs
    func numberOfSections(in tableView: UITableView) -> Int {
        return archive.sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = archive.sections[section]
        return section.sectionItem
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard var document = getSelectedDocument(from: indexPath) else { return }
        os_log("Selected Document: %@", log: log, type: .debug, document.filename)

        // download document if it is not already available
        switch document.downloadStatus {
        case .local:
            performSegue(withIdentifier: "showDetails", sender: self)
        case .downloading:
            print("Downloading currently ...")
        case .iCloudDrive:
            print("Start download ...")
            document.download()
        }

        // avoid inverted colors in tags by deselecting the cell
        tableView.deselectRow(at: indexPath, animated: false)
    }

    // MARK: - optical changes
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let view = view as? UITableViewHeaderFooterView else { return }

        // change colors
        view.textLabel?.textColor = UIColor(named: "MainTextColor")
        view.backgroundView?.backgroundColor = UIColor(named: "MainBackgroundColor")
    }
}

extension MasterViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        guard let searchBarText = searchBar.text else { return }
        guard let searchBarScopeButtonTitles = searchBar.scopeButtonTitles else { return }
        archive.filterContentForSearchText(searchBarText, scope: searchBarScopeButtonTitles[selectedScope])

        // reload the table view data
        tableView.reloadData()
    }
}

extension MasterViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        guard let searchBarText = searchBar.text else { return }
        guard let searchBarScopeButtonTitles = searchBar.scopeButtonTitles else { return }
        archive.filterContentForSearchText(searchBarText, scope: searchBarScopeButtonTitles[searchBar.selectedScopeButtonIndex])

        // reload the table view data
        tableView.reloadData()
    }
}
