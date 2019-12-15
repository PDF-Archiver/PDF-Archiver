//
//  CustomDatePicker.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct CustomDatePicker: UIViewRepresentable {

    class Coordinator: NSObject, UIPickerViewDelegate {

        @Binding var date: Date

        init(date: Binding<Date>) {
            _date = date
        }

        @objc
        func valueChanged(_ datePicker: UIDatePicker) {
            date = datePicker.date
        }
    }

    @Binding var date: Date

    func makeUIView(context: UIViewRepresentableContext<CustomDatePicker>) -> UIDatePicker {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.addTarget(context.coordinator, action: #selector(context.coordinator.valueChanged(_:)), for: .valueChanged)
        return datePicker
    }

    func makeCoordinator() -> CustomDatePicker.Coordinator {
        return Coordinator(date: $date)
    }

    func updateUIView(_ view: UIDatePicker, context: UIViewRepresentableContext<CustomDatePicker>) {
        view.date = date
    }
}
