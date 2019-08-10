//
//  PDFQualityViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.08.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

class PDFQualityViewController: UITableViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let cells = tableView.visibleCells

        let pdfQuality = UserDefaults.standard.pdfQuality
        guard let selectedCell = cells.first(where: { Float($0.reuseIdentifier ?? "0") == pdfQuality.rawValue }) else { fatalError("Could not find the selected cell.") }
        selectedCell.accessoryType = .checkmark
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        guard let cell = tableView.cellForRow(at: indexPath) else {
            assertionFailure("Could not get table view row.")
            return
        }

        guard let reuseIdentifier = cell.reuseIdentifier,
            let level = Float(reuseIdentifier),
            let pdfQuality = UserDefaults.PDFQuality(rawValue: level) else {
                fatalError("Could not match PDF Quality of \(cell.reuseIdentifier ?? "NaN").")
        }
        UserDefaults.standard.pdfQuality = pdfQuality

        for visibleCell in tableView.visibleCells where visibleCell != cell {
            visibleCell.accessoryType = .none
        }
        cell.accessoryType = .checkmark
        cell.setSelected(false, animated: true)
    }
}
