<p align="center">
<a href="https://itunes.apple.com/app/apple-store/id1433801905?pt=118993774&ct=GitHub&mt=8" target="itunes_store">
  <img src="assets/AppIcon.svg" width="100px">
</a>
<br><br>
<a href="https://itunes.apple.com/app/apple-store/id1433801905?pt=118993774&ct=GitHub&mt=8" style="display:inline-block;overflow:hidden;background:url(https://linkmaker.itunes.apple.com/assets/shared/badges/en-us/appstore-lrg.svg) no-repeat;width:135px;height:40px;"></a>
</p>


# PDF Archive Viewer

The PDF Archive Viewer shows documents in iCloud Drive.
It is a helper of the macOS App [PDF Archiver](https://github.com/pdf-Archiver/pdf-archiver).


## :rocket: Usage

Test the Beta-Version with [Testflight](https://testflight.apple.com/join/luoTZhap) <a href="https://testflight.apple.com/join/luoTZhap" target="itunes_store">
  <img src="https://developer.apple.com/assets/elements/icons/testflight/testflight-128x128_2x.png" width="20px">
</a>.


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
* Get in contact with us at [Slack](https://pdf-archiver.slack.com).


## :octocat: How to contribute
Rate the App in the [App Store](https://itunes.apple.com/app/apple-store/id1433801905?pt=118993774&ct=GitHub&mt=8&action=write-review).

All [contributions](https://github.com/PDF-Archiver/PDF-Archiver/blob/develop/.github/CONTRIBUTING.md) are welcome!
Feel free to contribute to this project.
Submit pull requests or contribute tutorials - whatever you have to offer, it would be appreciated!
