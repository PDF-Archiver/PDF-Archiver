//
//  CustomInputView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 27.04.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import UIKit

protocol SuggestionInputViewDelegate: AnyObject {
    func suggestionInputViewController(_ suggestionInputViewController: SuggestionInputViewController, userTabbed button: UIButton)
}

class SuggestionInputViewController: UIViewController {

    static let height = CGFloat(45)

    weak var delegate: SuggestionInputViewDelegate?
    var suggestions = [String]() {
        didSet {
            setupButtonTitles()
        }
    }

    private let button1 = UIButton()
    private let button2 = UIButton()
    private let button3 = UIButton()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        for button in [button1, button2, button3] {
            view.addSubview(button)
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            button.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            SuggestionInputViewController.customize(button)
            button.addTarget(self, action: #selector(action(sender:)), for: .touchUpInside)
        }

        button1.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        button1.trailingAnchor.constraint(equalTo: button2.leadingAnchor).isActive = true
        button2.trailingAnchor.constraint(equalTo: button3.leadingAnchor).isActive = true
        button3.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        button1.widthAnchor.constraint(equalTo: button2.widthAnchor).isActive = true
        button1.widthAnchor.constraint(equalTo: button3.widthAnchor).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupButtonTitles()
    }

    private func setupButtonTitles() {
        if let element = suggestions[safe: 0] {
            button1.setTitle(element, for: .normal)
        } else {
            button1.setTitle(nil, for: .normal)
        }

        if let element = suggestions[safe: 1] {
            button2.setTitle(element, for: .normal)
        } else {
            button2.setTitle(nil, for: .normal)
        }

        if let element = suggestions[safe: 2] {
            button3.setTitle(element, for: .normal)
        } else {
            button3.setTitle(nil, for: .normal)
        }
    }

    private static func customize(_ button: UIButton) {

        button.translatesAutoresizingMaskIntoConstraints = false

        button.contentMode = .center
        button.backgroundColor = .paKeyboardBackground
        button.setTitleColor(.paDarkGray, for: .normal)
        button.titleLabel?.lineBreakMode = .byTruncatingTail
    }

    @objc
    private func action(sender: UIButton) {
        delegate?.suggestionInputViewController(self, userTabbed: sender)
    }
}

extension Collection {
    subscript(safe index: Index) -> Iterator.Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
