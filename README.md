# elijah_dump

Dump and parse existing pages for Madrid.rb from Jottit

## Usage

Simply run `elijah_dump.rb`. 

Gets a list of pages and tries to convert them. If successful, writes the results in JSON and YAML formats, as `out/meetings.json` and `out/meetings.yml`.

**WARNING** It overwrites existing versions of these files!

It will create the `out` directory if it doesn't exist yet.

## Output data

The output file contains an array of meetings. For each of them, these fields can be present (when they're not, they have no value or haven't been correctly parsed).

*	`title`
*	`details`
*	`details_md`
*	`meeting_date`
*	`meeting_time`
*	`offered_by`
*	`offered_by_html`
*	`attendees`
*	`venue`
*	`map_url`
*	`original_url`
*	`topics` 

`attendees` contains a list of (usually) Twitter handles or (sometimes) plain names.

`offered_by` contains a list of the sponsors' urls. `offered_by_html` contains the raw HTML for that info (normally with images).

`topics` contains an array or topics (talks) that took place during the meeting. Each topic can include:

*	`title`
*	`details`	
*	`details_md`
*	`video_url`
*	`slides_url`
*	`speakers` 

Again, `speakers` is an array that contains the list of speakers for a given topic. Each can include:

*	`speaker_name`
*	`speaker_handle`
*	`speaker_bio`
*	`speaker_bio_md`

These fields contain raw HTML: `details`, `speaker_bio`, `offered_by_html`. 

These fields contain Markdown: `details_md` (both in a `meeting` and in each `topic`) and `speaker_bio_md`.

The rest contain plain text.

### Markdown conversion

Fields with HTML are converted back to Markdown thanks to [reverse_markdown](https://github.com/xijo/reverse_markdown).

Original pages were written in Markdown but the parsing uses Nokogiri to navigate through the raw HTML, so the results are in HTML too. However, Markdown source is preferred to repopulate the new site.

Fortunately, reverse_markdown seems to perform a great job at reverting the process.

### Page caching

To accelerate processing (specially during development), pages are downloaded only once and stored under the directory `page_cache`

## Results included!!

If you are interested in this it's most probably because you just want the results. To make your life easier, they are included in the repository. Just get them from `out` and be done. 

For the same price, the cached pages are included too!!

## Current issues

*	Sections not identified as speaker, attendees, etc are just appended to `details`.

*	<strike>Assumes one talk per meeting. In meetings with more than one talk (or more than one speaker), speaker data is not accurate.</strike> It now supports multi topic (talk) and multi speaker.

*	<strike>Right now, It only gets pages from Jottit (no GitHub pages yet!)</strike> Pages from GitHub now work!

## Author

Josep Egea. March 2015
