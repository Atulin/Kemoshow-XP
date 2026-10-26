# KemoShow

## Project description

Provide a slideshow interface for Kemono-type websites. All media (images and videos alike) of a given author, or matching a given search result, are
displayed in a single slideshow without pagination. Accessible on desktop with full keyboard navigation, as well as on mobile with swipe gestures.
On desktop, videos should be seekable with keyboard controls, without interfering with slideshow navigation. Videos in generalshould have an additional,
thin (2-3px) progress bar stuch to the top of the screen for when the default controls fade out, for optimal viewing experience.

The API spec can be found in the [openapi.json](openapi.json) file.

## Design

- The application should initially support three servers:
  - `pawchive.pw` (default)
  - `kemono.cr`
  - `coomer.su`
- The initial screen should contain a switch between "post search" and "author search"
- If author search is selected, the searchbar should autocomplete based on a list of authors obtainable from `https://[server url]/api/v1/creators.txt`
  - WARNING: for legacy reasons, the reques must set `Accept: text/css` header to fetch this list!
  - The list should be fetched in the background on startup and cached for the runtime of the app
- Once the user has selected an author or entered a search term, the slideshow should open
- The slideshow should allow the user to seamlessly swipe between flattened media attachments of all posts. For example, if `post1` contains `media1` and `media2`,
  `post2` contains `media3`, and `post3` contains `media4`, the user should be able to swipe between `media1`, `media2`, `media3`, `media4`, etc.
- Once the user gets close to the end of the list (5 media left) the app should fetch more posts
  - The API uses offset pagination with `?o=[offset]` query parameter

## API tips

- Media is served from `nx` subdomains, specifically `https://n2.pawchive.pw/data/`, `https://n4.kemono.cr/data/`, `https://n3.coomer.st/data/` respectively.

## Stack

- Flutter 3.47.8
- Dart 3.13.7
- media_kit 1.2.6 (video player, [docs](https://pub.dev/documentation/media_kit/latest/))
- dart_mappable 4.10.0 (JSON deserialization, [docs](https://pub.dev/documentation/dart_mappable/latest/))
