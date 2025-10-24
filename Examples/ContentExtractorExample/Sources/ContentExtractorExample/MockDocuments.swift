//
//  MockDocuments.swift
//  ContentExtractorExample
//
//  Created by Julian Kahnert on 24.10.25.
//

import FoundationModels
import Playgrounds

enum MockDocuments {
    static let invoice = """
    INVOICE

    MEDIAMARKT
    Sample Street 123
    12345 Berlin

    Date: 03/15/2025
    Invoice Number: MM-2025-123456

    Item                            Qty      Unit Price     Total
    ----------------------------------------------------------------
    Samsung Galaxy S25              1        €899.00        €899.00
    Protective Case                 1         €29.99         €29.99
    Screen Protector                1         €14.99         €14.99

    Subtotal:                                               €943.98
    VAT 19%:                                                €179.36

    Total Amount:                                         €1,123.34

    Payment Method: Debit Card

    Thank you for your purchase!
    """

    static let contract = """
    RENTAL AGREEMENT

    Between
    Max Mustermann
    Sample Road 1, 10115 Berlin

    and

    Erika Musterfrau
    Example Street 42, 10115 Berlin

    the following rental agreement is concluded:

    § 1 Rental Property
    The apartment on the 3rd floor left is being rented
    Living space: approx. 65 m²
    Number of rooms: 2.5

    § 2 Rental Start and Duration
    The tenancy begins on 04/01/2025
    It is concluded for an indefinite period

    § 3 Rent
    The monthly base rent is: €850.00
    Utilities (advance payment): €150.00
    Total rent: €1,000.00

    Berlin, 03/01/2025
    """

    static let medicalReport = """
    MEDICAL REPORT

    Dr. med. Schmidt
    Specialist in Internal Medicine
    Health Street 10
    20095 Hamburg

    Patient: Max Mustermann
    Date of Birth: 06/15/1985

    Date: 03/20/2025

    Diagnosis:
    - Common Cold
    - Elevated Body Temperature (38.5°C)

    Treatment:
    - Bed rest recommended
    - Paracetamol 500mg as needed
    - Plenty of fluids

    Sick Leave: 03/21/2025 - 03/25/2025

    Follow-up if symptoms persist

    Sincerely,
    Dr. Schmidt
    """

    static let insurance = """
    INSURANCE POLICY

    Allianz Insurance AG
    Main Street 50
    80331 Munich

    Policyholder: Max Mustermann
    Policy Number: V-2025-987654

    CAR INSURANCE

    Vehicle: VW Golf 8
    License Plate: B-MM 1234
    First Registration: 01/2023

    Insurance Start: 04/01/2025
    Insurance Duration: 12 months

    Coverage:
    - Liability
    - Comprehensive (Deductible €500)

    Annual Premium: €890.00
    Payment Method: Annual

    Munich, 03/10/2025
    """
}
