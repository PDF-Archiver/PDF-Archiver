//
//  TestViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import SwiftUI
import UIKit

class TestViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let viewModel = ArchiveViewModel()
        let view = ArchiveView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        self.present(viewController, animated: false, completion: nil)
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
