//
//  DateDescriptionViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 21.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SkyFloatingLabelTextField
import UIKit

protocol DateDescriptionViewControllerDelegate: AnyObject {
    func updateDateDescription(_ date: Date, _ description: String?)
}

class DateDescriptionViewController: UIViewController {

    private let date: Date
    private let specification: String?

    init(date: Date, description: String?) {
        self.date = date
        self.specification = description

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    weak var delegate: DateDescriptionViewControllerDelegate?

    @IBOutlet weak var datePickerView: UIDatePicker!

    @IBOutlet weak var descriptionTextField: SkyFloatingLabelTextField!

    @IBAction private func datePickerChanged(_ sender: UIDatePicker) {
        delegate?.updateDateDescription(datePickerView.date, descriptionTextField.text)
    }

    @IBAction private func descriptionTextFieldChanged(_ sender: UITextField) {
        guard let text = sender.text else { return }
        delegate?.updateDateDescription(datePickerView.date, text)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        datePickerView.date = date
        descriptionTextField.text = specification
        descriptionTextField.titleFormatter = { $0 }
        descriptionTextField.titleFont = .paLabelTitle
        descriptionTextField.titleColor = .paLightGray
        descriptionTextField.placeholder = NSLocalizedString("document_description.placeholder", comment: "Document label text field placeholder.")
        descriptionTextField.title = NSLocalizedString("document_description.title", comment: "Document label text field title.")
        descriptionTextField.placeholderColor = .paPlaceholderGray

        descriptionTextField.borderStyle = .none
        descriptionTextField.clearButtonMode = .always
    }

    func update(date: Date?, description: String?) {
        datePickerView.date = date ?? Date()

        // remove PDF Archive default decription and tags
        if description?.starts(with: Constants.documentDescriptionPlaceholder) ?? false {
            descriptionTextField.text = ""
        } else {
            descriptionTextField.text = description
        }
    }
}
