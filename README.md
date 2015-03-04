# elijah_dump

Dump and parse existing pages for Madrid.rb from Jottit

## Usage

Simply run `elijah_dump.rb`. 

Gets a list of pages and tries to convert them. If successful, writes the results in JSON and YAML formats, as `out/meetings.json` and `out/meetings.yml`.

**WARNING** It overwrites existing versions of these files!

It will create the `out` directory if it doesn't exists yet.

## Output data

The output file contains an array of meetings. For each of them, these fields can be present (if not, they are empty or haven't been correctly parsed).

*	`title`
*	`details`
*	`meeting_date`
*	`meeting_time`
*	`venue`
*	`speaker_name`
*	`speaker_handle`
*	`speaker_bio`
*	`video_url`
*	`offered_by`
*	`offered_by_html`
*	`attendees`
*	`map_url`
*	`slides_url`
*	`original_url`

These fields contain raw HTML: `details`, `speaker_bio`, `offered_by_html`. The rest contain plain text.

`attendees` contains a list of (usually) Twitter handles or (sometimes) plain names.

`offered_by` contains a list of the sponsors' urls. `offered_by_html` contains the raw HTML (normally with images).

### Page caching

To accelerate processing (specially during development), pages are downloaded only once and stored under the directory `page_cache`

## Results included!!

If you are interested in this it's most probably because you just want the results. To make your life easier, they are included in the repository. Just get them from `out` and be done. 

For the same price, the cached pages are included too!!

## Current issues

*	Assumes one talk per meeting. In meetings with more than one talk (or more than one speaker), speaker data is not accurate.

*	Sections not identified as speaker, attendees, etc are just appended to `details`.

*	<strike>Right now, It only gets pages from Jottit (no GitHub pages yet!)</strike> Pages from GitHub now work!

## Author

Josep Egea. March 2015
