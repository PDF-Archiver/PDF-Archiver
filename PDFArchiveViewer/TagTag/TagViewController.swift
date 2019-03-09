//
//  TagViewController.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 07.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import UIKit

class TagViewController: UIViewController {

    @IBOutlet weak var documentTableView: UITableView!

    var currentSections = [TableSection<String, Document>]()

    // Table view cells are reused and should be dequeued using a cell identifier.
    private let cellIdentifier = "TagDocumentTableViewCell"

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        documentTableView.register(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)

        // Do any additional setup after loading the view.
//        documentTableView.delegate = self
//        documentTableView.dataSource = self

        // get documents
        let newDocuments = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)

        // sort documents by Date (descending) and Name (ascending)
        let sortedDocuments: [Document] = Array(newDocuments).sorted().reversed()

        // create table sections
        currentSections = TableSection.group(rowItems: sortedDocuments) { (document) in
            let calender = Calendar.current
            return String(calender.component(.year, from: document.date))
        }.reversed()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension TagViewController: UITableViewDataSource {
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

    private func getDocument(from indexPath: IndexPath) -> Document? {
        let tableSection = currentSections[indexPath.section]
        return tableSection.rowItems[indexPath.row]
    }
}

extension TagViewController: UITableViewDelegate {

}
