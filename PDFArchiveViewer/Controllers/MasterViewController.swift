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
    @IBOutlet var searchFooter: SearchFooter!

    var detailViewController: DetailViewController?
    var archive = Archive()
    var documentsQuery = DocumentsQuery()
    let searchController = UISearchController(searchResultsController: nil)

    // Table view cells are reused and should be dequeued using a cell identifier.
    private let cellIdentifier = "DocumentTableViewCell"

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)

        // setup data delegate
        self.documentsQuery.delegate = self

        // Setup the Search Controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Documents"
        navigationItem.searchController = searchController
        definesPresentationContext = true

        // Setup the Scope Bar
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

    // MARK: - Segues
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetails",
            let indexPath = self.tableView.indexPathForSelectedRow,
            let document = getSelectedDocument(from: indexPath) {

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
            let indexPath = self.tableView.indexPathForSelectedRow,
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
        }
    }

    // MARK: - Private instance methods
    private func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    private func isFiltering() -> Bool {
        let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
        return searchController.isActive && (!searchBarIsEmpty() || searchBarScopeIsFiltering)
    }

    private func getSelectedDocument(from indexPath: IndexPath) -> Document? {
        let tableSection = self.archive.sections[indexPath.section]
        return tableSection.rowItems[indexPath.row]
    }
}

// MARK: - Delegates
extension MasterViewController: DocumentsQueryDelegate {
    func documentsQueryResultsDidChangeWithResults(documents: [Document], tags: Set<Tag>) {
        self.archive.setAllDocuments(documents.sorted().reversed())
        self.archive.availableTags = tags

        // setup background view controller
        if documents.isEmpty {
            self.tableView.backgroundView = Bundle.main.loadNibNamed("EmptyBackgroundView", owner: nil, options: nil)?.first as? UIView
        } else {
            self.tableView.backgroundView = nil
        }

        // setup search toolbar
        self.searchController.searchBar.scopeButtonTitles = ["All"] + self.archive.years

        // update the filtered documents
        let searchBar = searchController.searchBar
        let searchBarText = searchBar.text ?? ""
        if let scopeButtonTitles = searchBar.scopeButtonTitles {
            self.archive.filterContentForSearchText(searchBarText, scope: scopeButtonTitles[searchBar.selectedScopeButtonIndex])
        } else {
            self.archive.filterContentForSearchText(searchBarText, scope: "All")
        }

        // reload the table view data
        self.tableView.reloadData()
    }
}

extension MasterViewController: UITableViewDataSource {

    // MARK: - required stubs
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        let tableSection = self.archive.sections[section]
        return tableSection.rowItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // get the desired cell
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier, for: indexPath) as? DocumentTableViewCell else {
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
        return self.archive.sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = self.archive.sections[section]
        return section.sectionItem
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let document = getSelectedDocument(from: indexPath) else { return }
        print(document.filename)
        os_log("Selected Document: %@", log: self.log, type: .debug, document.filename)

        // download document if it is not already available
        switch document.downloadStatus {
        case .local:
            self.performSegue(withIdentifier: "showDetails", sender: self)
        case .downloading:
            print("Downloading currently ...")
        case .iCloudDrive:
            print("Start download ...")
            document.download()
        }
    }

    // MARK: - optical changes
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let view = view as? UITableViewHeaderFooterView else { return }

        // change colors
        view.textLabel?.textColor = UIColor(named: "Headline1")
        view.backgroundView?.backgroundColor = UIColor(named: "OffWhite")
    }
}

extension MasterViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        guard let searchBarText = searchBar.text else { return }
        guard let searchBarScopeButtonTitles = searchBar.scopeButtonTitles else { return }
        self.archive.filterContentForSearchText(searchBarText, scope: searchBarScopeButtonTitles[selectedScope])

        // reload the table view data
        self.tableView.reloadData()
    }
}

extension MasterViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        guard let searchBarText = searchBar.text else { return }
        guard let searchBarScopeButtonTitles = searchBar.scopeButtonTitles else { return }
        self.archive.filterContentForSearchText(searchBarText, scope: searchBarScopeButtonTitles[searchBar.selectedScopeButtonIndex])

        // reload the table view data
        self.tableView.reloadData()
    }
}
