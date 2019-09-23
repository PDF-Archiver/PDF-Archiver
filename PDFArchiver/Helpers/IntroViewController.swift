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

    private let items = [
        OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "scan"),
                           title: NSLocalizedString("intro.scan.title", comment: "Intro: Scan Title"),
                           description: NSLocalizedString("intro.scan.description", comment: "Intro: Scan Description"),
                           pageIcon: UIImage(systemName: "doc.text.viewfinder")!.imageWithBorder(width: 7, color: .clear)!,
                           color: .paBackground,
                           titleColor: .paDarkRed,
                           descriptionColor: .paDarkGray,
                           titleFont: .introTitle,
                           descriptionFont: .introDescription),

        OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "tag-1"),
                           title: NSLocalizedString("intro.tag.title", comment: "Intro: Tag Title"),
                           description: NSLocalizedString("intro.tag.description", comment: "Intro: Tag Description"),
                           pageIcon: UIImage(systemName: "tag")!.imageWithBorder(width: 7, color: .clear)!,
                           color: .paBackground,
                           titleColor: .paDarkRed,
                           descriptionColor: .paDarkGray,
                           titleFont: .introTitle,
                           descriptionFont: .introDescription),

        OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "find"),
                           title: NSLocalizedString("intro.find.title", comment: "Intro: Find Title"),
                           description: NSLocalizedString("intro.find.description", comment: "Intro: Find Description"),
                           pageIcon: UIImage(systemName: "archivebox")!.imageWithBorder(width: 7, color: .clear)!,
                           color: .paBackground,
                           titleColor: .paDarkRed,
                           descriptionColor: .paDarkGray,
                           titleFont: .introTitle,
                           descriptionFont: .introDescription),

        OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "piggy-bank"),
                           title: NSLocalizedString("intro.subscription.title", comment: "Intro: Subscription Title"),
                           description: NSLocalizedString("intro.subscription.description", comment: "Intro: Subscription Description"),
                           pageIcon: UIImage(systemName: "dollarsign.circle")!.imageWithBorder(width: 0, color: .clear)!,
                           color: .paBackground,
                           titleColor: .paDarkRed,
                           descriptionColor: .paDarkGray,
                           titleFont: .introTitle,
                           descriptionFont: .introDescription),

        OnboardingItemInfo(informationImage: #imageLiteral(resourceName: "start"),
                           title: NSLocalizedString("intro.last.title", comment: "Intro: Last Page Title"),
                           description: NSLocalizedString("intro.last.description", comment: "Intro: Last Page Description"),
                           pageIcon: UIImage(systemName: "chevron.right.circle")!.imageWithBorder(width: 0, color: .clear)!,
                           color: .paBackground,
                           titleColor: .paDarkRed,
                           descriptionColor: .paDarkGray,
                           titleFont: .introTitle,
                           descriptionFont: .introDescription)
    ]

    init() {
        super.init(nibName: nil, bundle: nil)

        // adapt to iOS 13 presentation defaults
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let onboarding = PaperOnboarding(pageViewBottomConstant: 100)
        onboarding.backgroundColor = .paBackground
        onboarding.delegate = self
        onboarding.dataSource = self
        onboarding.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(onboarding)
        view.backgroundColor = .paBackground

        // add constraints
        onboarding.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        onboarding.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
        onboarding.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 15).isActive = true
        onboarding.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -15).isActive = true
    }
}

extension IntroViewController: PaperOnboardingDataSource {
    func onboardingItemsCount() -> Int {
        return items.count
    }

    func onboardingItem(at index: Int) -> OnboardingItemInfo {
        return items[index]
    }

    func onboardingPageItemColor(at index: Int) -> UIColor {
        return .paDarkGray
    }

    func onboardinPageItemRadius() -> CGFloat {
        return CGFloat(7)
    }

    func onboardingPageItemSelectedRadius() -> CGFloat {
        return CGFloat(17)
    }
}

extension IntroViewController: PaperOnboardingDelegate {

    var enableTapsOnPageControl: Bool {
        return false
    }

    func onboardingWillTransitonToLeaving() {
        dismiss(animated: true, completion: nil)
    }

    func onboardingConfigurationItem(_ item: OnboardingContentViewItem, index _: Int) {
        item.informationImageHeightConstraint?.constant = view.frame.width * 0.25
    }
}

extension UIImage {
    fileprivate func imageWithBorder(width: CGFloat, color: UIColor) -> UIImage? {
        let square = CGSize(width: min(size.width, size.height) + width * 2, height: min(size.width, size.height) + width * 2)
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: square))
        imageView.contentMode = .center
        imageView.image = self
        imageView.tintColor = .paDarkGray
        imageView.layer.borderWidth = width
        imageView.layer.borderColor = color.cgColor
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        imageView.layer.render(in: context)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}
