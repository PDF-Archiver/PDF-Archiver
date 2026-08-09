//
//  Tags.swift
//  ArchiverLib
//

import Testing

extension Tag {
    /// Tests that compare rendered images against committed reference PNGs.
    ///
    /// Rendering depends on the OS version, the installed fonts and the host
    /// platform, so a reference recorded locally will not match on the GitHub
    /// Actions VM. The `ArchiverLib-CI` test plan therefore excludes this tag;
    /// the default `ArchiverLib` plan runs them locally.
    @Tag static var snapshots: Self
}
