//
//  IntroViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.05.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping

import paper_onboarding
import UIKit

class IntroViewController: UIViewController {

    private let titleFont = UIFont(name: "AvenirNext-Bold", size: 65)!
    private let descriptionFont = UIFont(name: "AvenirNext-Regular", size: 17)!

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let onboarding = PaperOnboarding(pageViewBottomConstant: 100)
        onboarding.backgroundColor = .paWhite
        onboarding.dataSource = self
        onboarding.delegate = self
        onboarding.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(onboarding)

        // add constraints
        for attribute: NSLayoutConstraint.Attribute in [.left, .right, .top, .bottom] {
            let constraint = NSLayoutConstraint(item: onboarding,
                                                attribute: attribute,
                                                relatedBy: .equal,
                                                toItem: view,
                                                attribute: attribute,
                                                multiplier: 1,
                                                constant: 0)
            view.addConstraint(constraint)
        }
    }
}

extension IntroViewController: PaperOnboardingDataSource {
    func onboardingItemsCount() -> Int {
        return 4
    }

    func onboardingItem(at index: Int) -> OnboardingItemInfo {
        let items = [
            OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "scan"),
                               title: NSLocalizedString("intro.scan.title", comment: "Intro: Scan Title"),
                               description: NSLocalizedString("intro.scan.description", comment: "Intro: Scan Description"),
                               pageIcon: #imageLiteral(resourceName: "File"),
                               color: .paWhite,
                               titleColor: .paDarkRed,
                               descriptionColor: .paDarkGray,
                               titleFont: titleFont,
                               descriptionFont: descriptionFont),

            OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "tag-1"),
                               title: NSLocalizedString("intro.tag.title", comment: "Intro: Tag Title"),
                               description: NSLocalizedString("intro.tag.description", comment: "Intro: Tag Description"),
                               pageIcon: #imageLiteral(resourceName: "Tag"),
                               color: .paWhite,
                               titleColor: .paDarkRed,
                               descriptionColor: .paDarkGray,
                               titleFont: titleFont,
                               descriptionFont: descriptionFont),

            OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "find"),
                               title: NSLocalizedString("intro.find.title", comment: "Intro: Find Title"),
                               description: NSLocalizedString("intro.find.description", comment: "Intro: Find Description"),
                               pageIcon: #imageLiteral(resourceName: "Archive"),
                               color: .paWhite, //paDarkGray
                               titleColor: .paDarkRed,
                               descriptionColor: .paDarkGray, //paWhite
                               titleFont: titleFont,
                               descriptionFont: descriptionFont),

            OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "start"),
                               title: NSLocalizedString("intro.last.title", comment: "Intro: Last Page Title"),
                               description: NSLocalizedString("intro.last.description", comment: "Intro: Last Page Description"),
                               pageIcon: #imageLiteral(resourceName: "Logo"),
                               color: .paWhite,
                               titleColor: .paDarkRed,
                               descriptionColor: .paDarkGray,
                               titleFont: titleFont,
                               descriptionFont: descriptionFont)
        ]
        return items[index]
    }
}

extension IntroViewController: PaperOnboardingDelegate {

    func onboardingWillTransitonToLeaving() {
        dismiss(animated: true, completion: nil)
    }
}
