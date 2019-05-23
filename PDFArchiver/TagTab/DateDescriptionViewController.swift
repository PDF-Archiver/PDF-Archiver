//
//  DateDescriptionViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

protocol DateDescriptionViewControllerDelegate: AnyObject {
    func updateDateDescription(_ date: Date, _ description: String?)
}

class DateDescriptionViewController: UIViewController {

    init(date: Date, description: String?) {
        super.init(nibName: nil, bundle: nil)
        datePickerView.date = date
        descriptionTextField.text = description
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    weak var delegate: DateDescriptionViewControllerDelegate?

    @IBOutlet weak var datePickerView: UIDatePicker!

    @IBOutlet weak var descriptionTextField: UITextField!

    @IBAction private func datePickerChanged(_ sender: UIDatePicker) {
        delegate?.updateDateDescription(datePickerView.date, descriptionTextField.text)
    }

    @IBAction private func descriptionTextFieldChanged(_ sender: UITextField) {
        guard let text = sender.text else { return }
        delegate?.updateDateDescription(datePickerView.date, text)
    }

    func update(date: Date?, description: String?) {
        datePickerView.date = date ?? Date()

        // remove PDF Archive default decription and tags
        if description?.starts(with: Constants.documentDescriptionPlaceholder) ?? false{
            descriptionTextField.text = ""
        } else {
            descriptionTextField.text = description
        }
    }
}
