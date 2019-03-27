//
//  SubscriptionViewController.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 19.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length

import StoreKit
import UIKit

class SubscriptionViewController: UIViewController {

    let completion: (() -> Void)

    init(completion: @escaping (() -> Void)) {
        self.completion = completion

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var modalPresentationStyle: UIModalPresentationStyle {
        get { return .overCurrentContext }
        set { print("value that should be set: \(newValue)") }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // basic setup
        setupViews()
        setupConstraints()

        // optical changes in view
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    private lazy var blurEffectView: UIVisualEffectView = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        return blurView
    }()

    private lazy var actionView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var titleView: UILabel = {
        let view = UILabel()
        view.font = .systemFont(ofSize: 30)
        view.textAlignment = .center
        view.text = NSLocalizedString("subscription.title", comment: "Subscription View Controller title.")
        view.textColor = .paDarkGray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var textView: UITextView = {
        let view = UITextView()
        view.isScrollEnabled = false
        view.text = NSLocalizedString("subscription.text", comment: "Subscription View Controller description text.")
        view.textColor = .paLightGray
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: view.sizeThatFits(view.contentSize).height)
        return view
    }()

    private lazy var level1Button: UIButton = {
        let button = UIButton()

        let title: String
        if let product = IAP.service.products.first(where: { $0.productIdentifier == "SUBSCRIPTION_MONTHLY_IOS" }) {
            // TODO: this should be the "localizedTitle"
            title = product.productIdentifier
        } else {
            title = NSLocalizedString("subscription.level1", tableName: nil, bundle: .main, value: "Level 1", comment: "Subscription Level 1.")
        }
        button.setTitle(title, for: .normal)

        button.setTitleColor(.paWhite, for: UIControl.State.normal)
        button.layer.backgroundColor = UIColor.paDarkGray.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(subscribeLevel1), for: .touchUpInside)
        return button
    }()

    private lazy var level2Button: UIButton = {
        let button = UIButton()

        let title: String
        if let product = IAP.service.products.first(where: { $0.productIdentifier == "SUBSCRIPTION_YEARLY_IOS" }) {
            // TODO: this should be the "localizedTitle"
            title = product.productIdentifier
        } else {
            title = NSLocalizedString("subscription.level2", tableName: nil, bundle: .main, value: "Level 2", comment: "Subscription Level 1.")
        }
        button.setTitle(title, for: .normal)

        button.setTitleColor(.paWhite, for: UIControl.State.normal)
        button.layer.backgroundColor = UIColor.paLightGray.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(subscribeLevel2), for: .touchUpInside)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.paDarkGray, for: UIControl.State.normal)
        button.setTitle(NSLocalizedString("subscription.cancel", tableName: nil, bundle: .main, value: "Cancel", comment: "The cancel button"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        return button
    }()

    // MARK: - Actions

    @objc
    private func subscribeLevel1() {
        IAP.service.buyProduct("SUBSCRIPTION_MONTHLY_IOS")
    }

    @objc
    private func subscribeLevel2() {
        IAP.service.buyProduct("SUBSCRIPTION_YEARLY_IOS")
    }

    @objc
    private func cancel() {
        self.dismiss(animated: true, completion: completion)

//        if let completion = completion {
//            self.dismiss(animated: true, completion: completion(true))
//        } else {
//
//        }

    }

    // MARK: - Helper Functions

    private func setupViews() {
        view.addSubview(blurEffectView)
        actionView.addSubview(titleView)
        actionView.addSubview(textView)
        actionView.addSubview(level1Button)
        actionView.addSubview(level2Button)
        actionView.addSubview(cancelButton)
        view.addSubview(actionView)
    }

    private func setupConstraints() {
        let buttonHeight: CGFloat = 50
        let blurViewConstraints: [NSLayoutConstraint] = [
            blurEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]

        // setup maximum width to 0.75 screen width and default width to 400 for larger screens (e.g. iPad)
        let maxWidth = actionView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.75)
        maxWidth.priority = UILayoutPriority(rawValue: 1000)
        let defaultWidth = actionView.widthAnchor.constraint(equalToConstant: 400)
        defaultWidth.priority = UILayoutPriority(rawValue: 750)
        let actionViewConstraints: [NSLayoutConstraint] = [
            maxWidth,
            defaultWidth,
            actionView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]

        let titleViewConstraints: [NSLayoutConstraint] = [
            titleView.topAnchor.constraint(equalTo: actionView.topAnchor, constant: 8),
            titleView.heightAnchor.constraint(equalToConstant: 30),
            titleView.leadingAnchor.constraint(equalTo: actionView.leadingAnchor),
            titleView.trailingAnchor.constraint(equalTo: actionView.trailingAnchor)
        ]

        let textViewConstraints: [NSLayoutConstraint] = [
            textView.topAnchor.constraint(equalTo: titleView.bottomAnchor, constant: 8),
            textView.bottomAnchor.constraint(equalTo: level1Button.topAnchor, constant: -8),
            textView.leadingAnchor.constraint(equalTo: actionView.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: actionView.trailingAnchor, constant: -8)
        ]

        let level1ButtonConstraints: [NSLayoutConstraint] = [
            level1Button.heightAnchor.constraint(equalToConstant: buttonHeight),
            level1Button.leadingAnchor.constraint(equalTo: actionView.leadingAnchor),
            level1Button.trailingAnchor.constraint(equalTo: actionView.trailingAnchor),
            level1Button.bottomAnchor.constraint(equalTo: level2Button.topAnchor)
        ]

        let level2ButtonConstraints: [NSLayoutConstraint] = [
            level2Button.heightAnchor.constraint(equalToConstant: buttonHeight),
            level2Button.leadingAnchor.constraint(equalTo: actionView.leadingAnchor),
            level2Button.trailingAnchor.constraint(equalTo: actionView.trailingAnchor),
            level2Button.bottomAnchor.constraint(equalTo: cancelButton.topAnchor)
        ]

        // TODO: implement restore button

        let cancelButtonConstraints: [NSLayoutConstraint] = [
            cancelButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            cancelButton.leadingAnchor.constraint(equalTo: actionView.leadingAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: actionView.trailingAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: actionView.bottomAnchor)
        ]

        NSLayoutConstraint.activate(blurViewConstraints + actionViewConstraints + textViewConstraints + titleViewConstraints + level1ButtonConstraints + level2ButtonConstraints + cancelButtonConstraints)
    }
}

extension SubscriptionViewController: IAPServiceDelegate {
    func unlocked() {
        self.cancel()
    }
}
