<p align="center">
<a href="https://itunes.apple.com/app/pdf-archivar/id1352719750" target="itunes_store">
  <img src="assets/AppIcon.svg" width="200px">
</a>
</p>

<p align="center">
<a href="https://itunes.apple.com/app/pdf-archivar/id1352719750" target="itunes_store">
  <img src="assets/MacAppStoreBadge.svg">
</a>
</p>

# PDF Archiver
A tool for tagging files and archiving tasks.

### The Goal
Archive all incoming documents digitally to access and search them in an easier way.

### The Way
* Scan all incoming bills etc. and save them on your computer/iCloud in an *untagged* folder.
* Put the original paper documents in a folder, sorted by year. Don't care about bills/insurance papers etc.. Just leave all of them in one box for the each year.
* Open the **PDF Archiver** and start tagging. Your documents will be moved from the *untagged* to your *Archive* folder.

### The Look
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

### The Feel
<p align="center">
<img src="assets/example.gif" style="width: 75%;">
</p>

## :rocket: Usage
* Scan your documents, e.g. with [Scanbot](https://scanbot.io)
* Create an `Archive` folder in your iCloud Drive
* Select it in the *Preferences* panel (`CMD ,` ...obviously)
* Start tagging your files

## :scroll: Convention
* **Date:** `yyyy-mm-dd` Date of the document content
* **Description:** `--ikea-tradfri-gateway` Meaningful description of the document, `$CapitalLetters, $Spaces, ä, ö, ü, ß` will be replaced
* **Tags:** `__bill_ikea_iot` Tags which will help you to find the document in your archive

## :floppy_disk: Installation
* `git clone https://github.com/JulianKahnert/PDF-Archiver.git` get the project
* `cd PDF-Archiver && xcodebuild` build the app
* `cp -r "build/Release/PDF Archiver.app" ~/Applications/` copy it to your Applications folder
* Start **PDF Archiver** :rocket:

## <a name="pro-tips"></a>:mortar_board: Pro Tips
##### Scanbot
* **Easy document sync:** save your scans in iCloud Drive
* **Enable PDF content searching:** buy Scanbot Pro and turn on [OCR](https://en.wikipedia.org/wiki/Optical_character_recognition)
* **Let PDF Archiver recognize the scan date:** set a compatible filename template
    * In your Scanbot App go to: `Preferences > Advanced Settings > Filename Template`
    * Choose: `[year]-[month]-[day]--Scanbot-[Hours][Minutes][Seconds]`

##### PDF Archiver
* You can use keyboard shortcuts
    * `CMD ,`: open the preferences panel
    * `CMD o`: add new PDF documents
    * `CMD s`: save the current document in your archive
* Use the `TAB` key for fast field switching

## :octocat: How to contribute
All contributions are welcome!
Feel free to contribute to this project.
Submit pull requests, contribute tutorials or other wiki content - whatever you have to offer, it would be appreciated!

## :book: Credits and Thanks
[zngguvnf.org](https://zngguvnf.org) for the initial idea of the naming convention.
