<div align="center">
<a href="https://itunes.apple.com/app/pdf-archiver/id1352719750" target="itunes_store">
  <img src="assets/AppIcon.svg" width="200px">
</a><br><br>

<a href="https://itunes.apple.com/app/pdf-archiver/id1352719750" target="itunes_store">
  <img src="assets/MacAppStoreBadge.svg">
</a><br>

[![Build Status](https://travis-ci.org/PDF-Archiver/PDF-Archiver.svg?branch=master)](https://travis-ci.org/PDF-Archiver/PDF-Archiver)
[![Maintainability](https://api.codeclimate.com/v1/badges/e460629e748c442f5285/maintainability)](https://codeclimate.com/github/PDF-Archiver/PDF-Archiver/maintainability)
[![Receiving via Liberapay](https://img.shields.io/liberapay/receives/juliankahnert.svg)](https://liberapay.com/juliankahnert/)
[![Say Thanks!](https://img.shields.io/badge/Say%20Thanks-!-1EAEDB.svg)](https://saythanks.io/to/JulianKahnert)
</div>

# PDF Archiver

<p align="center">
<img src="assets/example.gif" style="width: 75%;">
</p>

Archive all incoming documents digitally to access and search them in an easier way.
Transfer the sorted documents to your smartphone or make a backup within seconds.

* Scan all incoming bills, letters etc. and save them on your computer/iCloud in an *untagged* folder.
* Put the original paper documents in a folder, sorted by year. Don't care about bills/insurance papers etc.. Just leave all of them in one box for the each year.
* Open the **PDF Archiver** and start tagging. Your documents will be moved from the *untagged* to your *Archive* folder.

## :rocket: Usage
* Scan your documents, e.g. with [Scanbot](https://scanbot.io)
* Create an `Archive` folder in your iCloud Drive
* Select it in the *Preferences* panel (`⌘ ,` ...obviously)
* Start tagging your files

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


## :floppy_disk: Installation
Download it from the Mac App Store:

<a href="https://itunes.apple.com/app/pdf-archiver/id1352719750" target="itunes_store">
  <img src="assets/MacAppStoreBadge.svg">
</a>

Or clone the repository and build it:
* Downloaded and install [Xcode.app](https://itunes.apple.com/app/xcode/id497799835)
* Get the project: `git clone https://github.com/PDF-Archiver/PDF-Archiver.git`
* Build the app: `cd PDF-Archiver && xcodebuild clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
* Copy it to your Applications folder: `cp -r "build/Release/PDF Archiver.app" ~/Applications/`
* Start **PDF Archiver** :rocket:

## <a name="pro-tips"></a>:mortar_board: Pro Tips
### Scanbot
* **Easy document sync:** save your scans in iCloud Drive
* **Enable PDF content searching:** buy [Scanbot](https://scanbot.io) Pro and turn on [OCR](https://en.wikipedia.org/wiki/Optical_character_recognition)
* **Let PDF Archiver recognize the scan date:** set a compatible filename template
    * In your Scanbot App go to: `Preferences > Advanced Settings > Filename Template`
    * Choose: `[year]-[month]-[day]--Scanbot-[Hours][Minutes][Seconds]`

### PDF Archiver
* Use the `↹` key for fast field switching
* You can use keyboard shortcuts from the [FAQs](https://pdf-archiver.io/faq)

## :interrobang: Help
* Take a look at the [FAQs](https://pdf-archiver.io/faq).
* Get in contact with us at [Slack](https://pdf-archiver.slack.com).

## :octocat: How to contribute
All [contributions](https://github.com/PDF-Archiver/PDF-Archiver/blob/develop/.github/CONTRIBUTING.md) are welcome!
Feel free to contribute to this project.
Submit pull requests or contribute tutorials - whatever you have to offer, it would be appreciated!

## :book: Thanks and Donations
* [**zngguvnf.org**](https://zngguvnf.org) discussing and creating this archive structure.
* [**Karl Voit**](http://karl-voit.at/managing-digital-photographs/) for the initial idea of a document naming convention.
* [**Nick Roach**](https://www.elegantthemes.com) for the [Icon](https://www.iconfinder.com/icons/1055071/document_file_icon).

<noscript><a href="https://liberapay.com/JulianKahnert/donate"><img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg"></a></noscript>
