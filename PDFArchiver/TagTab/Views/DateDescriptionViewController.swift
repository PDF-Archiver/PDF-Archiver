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
    func dateDescriptionView(_ sender: DateDescriptionViewController, didChangeDate date: Date)
    func dateDescriptionView(_ sender: DateDescriptionViewController, didChangeDescription description: String)
    func dateDescriptionView(_ sender: DateDescriptionViewController, shouldReturnFrom textField: UITextField)
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
        delegate?.dateDescriptionView(self, didChangeDate: datePickerView.date)
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
        descriptionTextField.addTarget(self, action: #selector(descriptionDidChange(_:)), for: .editingChanged)
        descriptionTextField.delegate = self
    }

    @objc
    private func descriptionDidChange(_ sender: SkyFloatingLabelTextField) {
        guard let text = sender.text else { return }
        delegate?.dateDescriptionView(self, didChangeDescription: text)
    }

    func update(date: Date) {
        datePickerView.setDate(date, animated: true)
    }
}

extension DateDescriptionViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.dateDescriptionView(self, shouldReturnFrom: textField)
        return true
    }
}
