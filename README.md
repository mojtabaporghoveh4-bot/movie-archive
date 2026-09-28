# Movie Archive

Catalog every movie on every hard drive, find anything in seconds, and carry the whole archive on your phone.

Created by **ArMo** · Telegram [@mocntrl](https://t.me/mocntrl). Works on **Windows** and **Android** from one codebase (Flutter).

## Features

- **Scan drives.** Pick a hard drive or folder. The app finds every movie file, reads the title and year from the file or folder name, and saves it. Each drive gets its own list; the Library shows all drives combined.
- **Automatic info and posters.** With a free TMDB key, the app fills in director, cast, genre, sub-genre, collection/franchise, language, country, rating, runtime, IMDb ID, and a poster, for every movie.
- **IMDb data.** With a free OMDb key, every movie also gets its IMDb rating and votes. Without a TMDB key, all info comes from IMDb through OMDb.
- **Exact match by IMDb ID.** Type or paste an IMDb ID (or link) for any movie (*Edit* or *Set IMDb ID*), and the app fetches everything for that exact movie. IMDb IDs in file or folder names (`Heat (1995) {imdb-tt0113277}`) are used automatically.
- **Search everything.** One search box covers title, director, actor, year, genre, language, collection, tags and notes.
- **Browse and filter** by genre, sub-genre, director, actor, year, decade, language, country, collection, your own tags, or drive. Combine filters (for example: *Director = Kubrick* and *Decade = 1970s*).
- **Add movies by hand**, by title, or by IMDb ID (`tt0111161`). Edit any field.
- **Organize folders.** Group a drive by director, actor, year, genre and more. *Links* mode uses no extra disk space (Windows junctions); *Move* mode really moves the movies on the same drive.
- **Find duplicates** across drives.
- **Stats**: movies per decade, top genres, languages, directors, actors, and storage per drive.
- **Spreadsheet export/import (CSV)** for Excel or Google Sheets.
- **Sync with your own cloud.** No accounts or servers of ours. See below.

## Download

Go to the **Actions** tab (latest build) or **Releases**, and download:

- `MovieArchive-Setup.exe`: Windows installer (Start menu and desktop shortcut, uninstall from Windows Settings).
- `MovieArchive-Windows-Portable.zip`: no install; unzip and run `MovieArchive.exe`.
- `MovieArchive-Android.apk`: open it on your phone and allow "install unknown apps".

## First steps

1. **Get free keys** (each user uses their own; one is enough, both is best):
   - **TMDB** (info and posters): make an account at [themoviedb.org](https://www.themoviedb.org/), then *Settings → API*, and copy the *API Key*.
   - **OMDb** (IMDb rating): get one at [omdbapi.com/apikey.aspx](https://www.omdbapi.com/apikey.aspx) (free: 1,000 movies per day).

   Paste them in the app under **Settings → Movie info**.
2. **Windows:** open **Drives → Scan a drive**, pick the folder, and give the drive a name (for example "WD Blue 2TB"). Info and posters are fetched automatically right after the scan.
3. Browse, search, and filter in **Library** and **Browse**.

Tip: movies named like `Title (Year)` or `Title.Year.1080p...` are matched best.

## Sync to your phone (with your own cloud)

The app does not need its own cloud. It uses whatever you already have: Google Drive, OneDrive, Dropbox, email, Telegram...

1. **Windows:** *Settings → Cloud sync folder*. Pick a folder inside your Google Drive / OneDrive / Dropbox folder. After every change the app saves `movie-archive.json` there, and your cloud app uploads it.
2. **Android:** *Settings → Import archive*, then pick `movie-archive.json` from Google Drive / Dropbox / OneDrive (they appear in the Android file picker), or from an email attachment. Choose **Replace** to update the phone.

No cloud? Use *Settings → Export archive* and send the file to yourself any way you like.

## Build it yourself

Every push to `main` builds both apps on GitHub Actions (free). Push a tag like `v1.0.0` to publish a Release.

Local build:

```
flutter pub get
flutter test
flutter build windows   # needs Visual Studio with "Desktop development with C++"
flutter build apk       # needs Android SDK
```

## Where data is stored

- Archive: `library.json` in the app data folder (`%APPDATA%\com.armo\movie_archive` on Windows).
- Posters: `posters\` next to it (the Windows app keeps copies so it works offline).
- Your TMDB key stays on your device and is never uploaded.

## Credits

Created by ArMo ([@mocntrl](https://t.me/mocntrl) on Telegram). Movie data and images from [TMDB](https://www.themoviedb.org/); IMDb ratings through [OMDb](https://www.omdbapi.com/). This product uses the TMDB API but is not endorsed or certified by TMDB.

License: MIT
