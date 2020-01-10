<p align="center">
<a href="https://apps.apple.com/app/apple-store/id1433801905?pt=118993774&ct=GitHub&mt=8" target="itunes_store">
  <img src="assets/AppIcon.svg" width="100px">
</a>
<br>
<br>
<a href="https://apps.apple.com/app/apple-store/id1433801905?pt=118993774&ct=GitHub&mt=8">
<img src="https://linkmaker.itunes.apple.com/assets/shared/badges/en-us/appstore-lrg.svg" width="135px">
</a>
</p>


# PDF Archive Viewer

The PDF Archive Viewer shows documents in iCloud Drive.
It is a helper of the macOS App [PDF Archiver](https://github.com/pdf-Archiver/pdf-archiver).


## :scroll: Convention
* **Date:** `yyyy-mm-dd` Date of the document content.
* **Description:** `--ikea-tradfri-gateway` Meaningful description of the document.
* **Tags:** `__bill_ikea_iot` Tags which will help you to find the document in your archive.
Capital letters, spaces and language specific characters (such as `ä, ö, ü, ß`) will be removed to maximize the filesystem compatibility.

Your archive will look like this:
```
.
└── Archive
    ├── 2017
    │   ├── 2017-05-12--apple-macbook__apple_bill.pdf
    │   └── 2017-01-02--this-is-a-document__bill_vacation.pdf
    └── 2018
        ├── 2018-04-30--this-might-be-important__work_travel.pdf
        ├── 2018-05-26--parov-stelar__concert_ticket.pdf
        └── 2018-12-01--master-thesis__finally_longterm_university.pdf
```

This structure is independent from your OS and filesystem and makes it very easy to search files ...
* ... by tag via a searchterm like: `_tagname`, starting with `_`
* ... by description via a searchterm like: `-descriptionword`, starting with `-`
* ... by tag or description via a searchterm like: `searchword`,  starting with the term
* ... and even the file content: have a look at the [Pro Tips](#pro-tips)!


## :interrobang: Help
* Take a look at the [FAQs](https://pdf-archiver.io/faq).
* Get in contact with us at [Discord](http://discord.pdf-archiver.io).


## :octocat: How to contribute
Rate the App in the [App Store](https://apps.apple.com/app/apple-store/id1433801905?pt=118993774&ct=GitHub&mt=8&action=write-review).

All [contributions](https://github.com/PDF-Archiver/PDF-Archiver/blob/develop/.github/CONTRIBUTING.md) are welcome!
Feel free to contribute to this project.
Submit pull requests or contribute tutorials - whatever you have to offer, it would be appreciated!


## :exclamation::question: Other

#### Build your own

Create a `Config.xcconfig` file at `PDFArchiver/Resources/Config.xcconfig` with this dummy secrets:
```xcconfig
APPSTORECONNECT_SHARED_SECRET = 123
SENTRY_DSN = 123
LOG_USER = 123
LOG_PASSWORD = 123
```

Now you should be good to go!
just build and run the App on your iPhone/iPad via Xcode.


#### License Update
```bash
# installation
brew install mono0926/license-plist/license-plist

# update license files
license-plist --add-version-numbers --output-path PDFArchiver/Resources/Settings.bundle --suppress-opening-directory
```
