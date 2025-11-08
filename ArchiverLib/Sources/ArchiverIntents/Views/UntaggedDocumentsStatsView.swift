//
//  UntaggedDocumentsStatsView.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import Shared
import SwiftUI

public struct UntaggedDocumentsStatsView: View {
    public enum Size {
        case small, medium, large
    }

    let untaggedDocuments: Int
    let size: Size
    let showActions: Bool

    public init(untaggedDocuments: Int, size: Size, showActions: Bool = true) {
        self.untaggedDocuments = untaggedDocuments
        self.size = size
        self.showActions = showActions
    }

    var actionButtons: some View {
         HStack {
            if untaggedDocuments <= 0 {
                Link(destination: DeepLink.scan.url) {
                    Label(String(localized: "Scan", bundle: .module), systemImage: "document.viewfinder")
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(
                    Capsule().fill(Color.paRedAsset)
                )
                .foregroundColor(.white)

            } else {
                Link(destination: DeepLink.scan.url) {
                    Image(systemName: "doc.viewfinder")
                }
                .padding(10)
                .background(Circle().fill(Color.gray.opacity(0.3)))

                Link(destination: DeepLink.tag.url) {
                    Label(String(localized: "Tag", bundle: .module), systemImage: "tag")
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Capsule().fill(Color.paRedAsset))
                .foregroundColor(.white)

            }
         }
        .padding(.top, 8)
    }

    public var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading) {
                if untaggedDocuments > 0 {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom, spacing: 8) {
                            Text(untaggedDocuments, format: .number)
                                .fontWeight(.black)
                                .foregroundStyle(.primary)

                            Image(systemName: "document.on.document")
                                .foregroundStyle(Color.paRedAsset)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .font(.largeTitle)
                    }
                } else {
                    allDocumentsTagged
                }

                Spacer()

                if showActions {
                    actionButtons
                }
            }

        case .medium:
            VStack(alignment: .leading) {
                if untaggedDocuments > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(untaggedDocuments, format: .number)
                            .font(.system(size: 48, weight: .black))

                        Image(systemName: "document.on.document")
                            .foregroundStyle(Color.paRedAsset)
                            .symbolRenderingMode(.hierarchical)
                            .font(.title)

                        Text("Untagged Documents", bundle: .module)
                            .foregroundStyle(.secondary)
                            .font(.body)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)

                        Spacer()
                    }
                } else {
                    allDocumentsTagged
                }

                Spacer()

                if showActions {
                    actionButtons
                }
            }
        case .large:
            VStack(alignment: .leading) {
                if untaggedDocuments > 0 {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom, spacing: 8) {
                            Text(untaggedDocuments, format: .number)
                                .fontWeight(.black)

                            Image(systemName: "document.on.document")
                                .foregroundStyle(Color.paRedAsset)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .font(.largeTitle)

                        Text("Untagged Documents", bundle: .module)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                } else {
                    allDocumentsTagged
                }

                Spacer()

                if showActions {
                    actionButtons
                }
            }
        }
    }

    private var allDocumentsTagged: some View {
        Text("All documents are tagged. 🎉", bundle: .module)
            .foregroundStyle(.secondary)
            .font(.caption)
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.seal.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.paRedAsset.opacity(0.4))
                    .frame(width: 80, height: 80)
                    .offset(x: 30, y: -30)

            }
    }
}

#Preview("Small") {
    List {
        Section {
            UntaggedDocumentsStatsView(untaggedDocuments: 0,
                                       size: .small)
        }
        Section {
            UntaggedDocumentsStatsView(untaggedDocuments: 0,
                                       size: .small)
        }
    }
}

#Preview("Medium") {
    List {
        Section {
            UntaggedDocumentsStatsView(untaggedDocuments: 0,
                                       size: .medium)
        }
        Section {
            UntaggedDocumentsStatsView(untaggedDocuments: 0,
                                       size: .medium)
        }
    }
}

#Preview("Large") {
    List {
        Section {
            UntaggedDocumentsStatsView(untaggedDocuments: 0,
                                       size: .large)
        }
        Section {
            UntaggedDocumentsStatsView(untaggedDocuments: 0,
                                       size: .large)
        }
    }
}
