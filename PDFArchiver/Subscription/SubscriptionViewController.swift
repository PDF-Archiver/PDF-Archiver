//
//  SubscriptionViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable function_body_length

import ArchiveLib
import os.log
import StoreKit
import UIKit

class SubscriptionViewController: UIViewController, Logging {

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // setup delegate
        IAP.service.delegate = self

        // setup button names
        guard !IAP.service.products.isEmpty else { return }
        updateButtonNames(with: IAP.service.products)
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
        view.font = .subscriptionTitle
        view.textAlignment = .center
        view.text = NSLocalizedString("subscription.title", comment: "Subscription View Controller title.")
        view.textColor = .paDarkGray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var textView: UITextView = {
        let view = UITextView()
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .paLightGray
        view.text = NSLocalizedString("subscription.text", comment: "Subscription View Controller description text.")
        view.isScrollEnabled = true
        view.isSelectable = false
        view.isEditable = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var level1Button: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .subscriptionButton
        button.setTitle("Level 1", for: .normal)
        button.setTitleColor(.paWhite, for: .normal)
        button.layer.backgroundColor = UIColor.paDarkGray.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(subscribeLevel1), for: .touchUpInside)
        return button
    }()

    private lazy var level2Button: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .subscriptionButton
        button.setTitle("Level 2", for: .normal)
        button.setTitleColor(.paWhite, for: .normal)
        button.layer.backgroundColor = UIColor.paLightGray.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(subscribeLevel2), for: .touchUpInside)
        return button
    }()

    private lazy var restoreButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .paText
        button.setTitleColor(.paDarkGray, for: .normal)
        button.layer.backgroundColor = UIColor.paLightGray.cgColor.copy(alpha: 0.3)
        button.setTitle(NSLocalizedString("subscription.restore", tableName: nil, bundle: .main, value: "Restore", comment: "The restore button"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(restore), for: .touchUpInside)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .paText
        button.setTitleColor(.paDarkGray, for: .normal)
        button.setTitle(NSLocalizedString("subscription.cancel", tableName: nil, bundle: .main, value: "Cancel", comment: "The cancel button"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        return button
    }()

    // MARK: - Actions

    @objc
    private func subscribeLevel1() {
        IAP.service.buyProduct("SUBSCRIPTION_MONTHLY_IOS")
        cancel()
    }

    @objc
    private func subscribeLevel2() {
        IAP.service.buyProduct("SUBSCRIPTION_YEARLY_IOS_NEW")
        cancel()
    }

    @objc
    private func restore() {
        IAP.service.restorePurchases()
        cancel()
    }

    @objc
    private func cancel() {

        if !IAP.service.appUsagePermitted() {
            self.dismiss(animated: true, completion: completion)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - Helper Functions

    private func setupViews() {
        view.addSubview(blurEffectView)
        actionView.addSubview(titleView)
        actionView.addSubview(textView)
        actionView.addSubview(level1Button)
        actionView.addSubview(level2Button)
        actionView.addSubview(restoreButton)
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
            actionView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.9),
            actionView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]

        let titleViewConstraints: [NSLayoutConstraint] = [
            titleView.topAnchor.constraint(equalTo: actionView.topAnchor, constant: 8),
            titleView.heightAnchor.constraint(equalToConstant: 30),
            titleView.leadingAnchor.constraint(equalTo: actionView.leadingAnchor),
            titleView.trailingAnchor.constraint(equalTo: actionView.trailingAnchor)
        ]

        let textHeight = textView.heightAnchor.constraint(equalTo: titleView.heightAnchor, multiplier: 10)
        textHeight.priority = UILayoutPriority(rawValue: 750)
        let textViewConstraints: [NSLayoutConstraint] = [
            textHeight,
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
            level2Button.bottomAnchor.constraint(equalTo: restoreButton.topAnchor)
        ]

        let restoreButtonConstraints: [NSLayoutConstraint] = [
            restoreButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            restoreButton.leadingAnchor.constraint(equalTo: actionView.leadingAnchor),
            restoreButton.trailingAnchor.constraint(equalTo: actionView.trailingAnchor),
            restoreButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor)
        ]

        let cancelButtonConstraints: [NSLayoutConstraint] = [
            cancelButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            cancelButton.leadingAnchor.constraint(equalTo: actionView.leadingAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: actionView.trailingAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: actionView.bottomAnchor)
        ]

        NSLayoutConstraint.activate(blurViewConstraints + actionViewConstraints + textViewConstraints + titleViewConstraints + level1ButtonConstraints + level2ButtonConstraints + restoreButtonConstraints + cancelButtonConstraints)
    }

    private func updateButtonNames(with products: Set<SKProduct>) {
        for product in products {
            switch product.productIdentifier {
            case "SUBSCRIPTION_MONTHLY_IOS":
                guard let localizedPrice = product.localizedPrice else { continue }
                level1Button.setTitle(localizedPrice + " " + NSLocalizedString("per_month", comment: ""), for: .normal)
            case "SUBSCRIPTION_YEARLY_IOS_NEW":
                guard let localizedPrice = product.localizedPrice else { continue }
                level2Button.setTitle(localizedPrice + " " + NSLocalizedString("per_year", comment: ""), for: .normal)
            default:
                os_log("Could not find product:  %@", log: SubscriptionViewController.log, type: .error, product)
            }
        }
    }
}

extension SubscriptionViewController: IAPServiceDelegate {
    func unlocked() {
        self.cancel()
    }

    func found(products: Set<SKProduct>) {
        self.updateButtonNames(with: products)
    }
}
