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

import UIKit

class MasterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Properties
    @IBOutlet var tableView: UITableView!
    @IBOutlet var searchFooter: SearchFooter!

    var detailViewController: DetailViewController?
    var archive = Archive()
    var documentsQuery = DocumentsQuery()
    let searchController = UISearchController(searchResultsController: nil)

    // Table view cells are reused and should be dequeued using a cell identifier.
    private let cellIdentifier = "TableViewCell"

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()

        // setup data delegate
        self.documentsQuery.delegate = self

        // Setup the Search Controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Documents"
        navigationItem.searchController = searchController
        definesPresentationContext = true

        // Setup the Scope Bar
        // TODO: fix this scope dynamically
        searchController.searchBar.scopeButtonTitles = ["All", "2018", "2017", "2016"]
        searchController.searchBar.delegate = self

        // Setup the search footer
        tableView.tableFooterView = searchFooter

        if let splitViewController = splitViewController {
            let controllers = splitViewController.viewControllers
            // swiftlint:disable force_cast
            detailViewController = (controllers[controllers.count - 1] as! UINavigationController).topViewController as? DetailViewController
            // swiftlint:enable force_cast
        }

        // setup background view controller
        self.tableView.backgroundView = Bundle.main.loadNibNamed("EmptyBackgroundView", owner: nil, options: nil)?.first as? UIView
    }

    override func viewWillAppear(_ animated: Bool) {
        if let splitViewController = self.splitViewController,
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

    // MARK: - Table View
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering() {
            searchFooter.setIsFilteringToShow(filteredItemCount: self.archive.filteredDocuments.count, of: self.archive.documents.count)
            return self.archive.filteredDocuments.count
        }

        searchFooter.setNotFiltering()
        return self.archive.documents.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // get the desired cell
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier, for: indexPath) as? TableViewCell  else {
            fatalError("The dequeued cell is not an instance of TableViewCell.")
        }

        // update the cell document and content
        cell.document = self.archive.documents[indexPath.row]
        cell.layoutSubviews()
        return cell
    }

    // MARK: - Segues
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetails",
            let document = getSelectedDocument() {

            // download document if it is not already available
            switch document.downloadStatus {
            case .local:
                return true
            case .downloading:
                return false
            case .iCloudDrive:
                document.download()
                return false
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetails",
            let navigationController = segue.destination as? UINavigationController,
            let controller = navigationController.topViewController as? DetailViewController,
            let document = getSelectedDocument() {

            // "shouldPerformSegue" performs the document download
            if document.downloadStatus != .local {
                fatalError("Segue peparation, but the document could not be found locally!")
            }

            controller.detailDocument = document
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }

    // MARK: - Private instance methods

    private func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        self.archive.filteredDocuments = self.archive.documents.filter {( document: Document) -> Bool in
            let doesCategoryMatch = (scope == "All") || (document.folder == scope)

            if searchBarIsEmpty() {
                return doesCategoryMatch
            } else {
                // TODO: maybe also search in tags/date
                return doesCategoryMatch && document.specification.lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }

    private func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    private func isFiltering() -> Bool {
        let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
        return searchController.isActive && (!searchBarIsEmpty() || searchBarScopeIsFiltering)
    }

    private func getSelectedDocument() -> Document? {
        guard let indexPath = self.tableView.indexPathForSelectedRow else { return nil }

        let document: Document
        if isFiltering() {
            document = self.archive.filteredDocuments[indexPath.row]
        } else {
            document = self.archive.documents[indexPath.row]
        }
        return document
    }
}

// MARK: - Delegates
extension MasterViewController: DocumentsQueryDelegate {
    func documentsQueryResultsDidChangeWithResults(documents: [Document], tags: Set<Tag>) {
        self.archive.documents = documents.sorted().reversed()
        self.archive.availableTags = tags

        // setup background view controller
        if documents.isEmpty {
            self.tableView.backgroundView = Bundle.main.loadNibNamed("EmptyBackgroundView", owner: nil, options: nil)?.first as? UIView
        } else {
            self.tableView.backgroundView = nil
        }

        self.tableView.reloadData()
    }
}

extension MasterViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        guard let searchBarText = searchBar.text else { return }
        guard let searchBarScopeButtonTitles = searchBar.scopeButtonTitles else { return }
        filterContentForSearchText(searchBarText, scope: searchBarScopeButtonTitles[selectedScope])
    }
}

extension MasterViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        guard let searchBarText = searchBar.text else { return }
        guard let searchBarScopeButtonTitles = searchBar.scopeButtonTitles else { return }

        let scope = searchBarScopeButtonTitles[searchBar.selectedScopeButtonIndex]
        filterContentForSearchText(searchBarText, scope: scope)
    }
}
