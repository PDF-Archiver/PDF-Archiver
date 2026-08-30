# Choosing where documents live

The archive is a folder. You decide which one.

## Overview

PDF Archiver never copies your documents into a private store. It reads and
writes a folder you can open in Finder, and the choice of folder is the only
storage decision the app asks you to make.

### iCloud Drive

The default, and the reason the iPhone and the Mac show the same archive without
the app doing any syncing of its own. Documents live in the app's iCloud Drive
folder, visible in Files.app and Finder.

A document that has not been downloaded yet shows as a placeholder; the app
requests it when you open it.

### A folder you pick

On the Mac you can point the app at any folder — an external disk, a NAS mount,
a folder another sync tool already handles. The app watches it for changes, so
documents added by other means show up without an import step.

### The app's own container

On iOS you can also keep the archive inside the app. Nothing leaves the device
and nothing syncs. This is the right choice if you want the archive to stay on
one phone, and the wrong one if you ever want it on a second device — moving out
of the container later means moving the files yourself.

## Switching later

Changing the location does not migrate anything. The app starts watching the new
folder; the documents in the old one stay where they are. Move them yourself
first if you want to take them along — they are ordinary PDFs with ordinary
names, so a drag in Finder is the whole migration.
