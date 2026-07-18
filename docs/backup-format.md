# Oneiro backup formats

Oneiro can write two backup files from **Settings → Backup & Import** and can
import the Awoken-compatible text format back. Both are documented here.

## 1. Awoken-compatible text export (`.txt`)

A plain-text convention shared with the old "Awoken" lucid-dreaming tool, so
files stay interchangeable in both directions. UTF-8, LF line endings.

```
DREAMS FROM THE LUCID DREAMING TOOL - ONEIRO
<blank>
link: <project url>
<blank>
<blank>
----
<blank>
Date: Mon 18 May 2026
<blank>
Lucidity: No
<blank>
Dream:
<body: 1..n free-text lines, may be multi-paragraph>
<blank>
<blank>
----
<blank>
Date: ...
...next entry...
```

Rules:

- A line of **exactly four dashes** (`----`) precedes every entry, including
  the first. There is no trailing separator; the file ends with the last
  body plus blank lines.
- Only three labels exist: `Date: `, `Lucidity: ` (`Yes` or `No`), `Dream:`.
- Dates are `<Weekday> dd MMM yyyy` (e.g. `Mon 18 May 2026`). The exporter
  recomputes the weekday so it always matches; September is written `Sep`.
  Importers should also accept `Sept` and tolerate a mismatched weekday.
- Bodies are free text and may contain blank lines, `---` (three-dash)
  lines, and lines starting with spaces. Only `^----\s*$` splits entries.
- Entries are ordered newest dream day first.

On import, Oneiro skips entries whose `(dream date, whitespace-normalized
body)` already exists in the journal, so re-importing the same file is a
no-op.

## 2. JSON export (`.json`) — full fidelity

`oneiro/journal-export`, version 1. Pretty-printed (two-space indent).
Unlike the text format this preserves entry ids and timestamps, making it
the lossless backup option.

```json
{
  "format": "oneiro/journal-export",
  "version": 1,
  "app": "Oneiro",
  "exportedAt": "2026-05-20T12:00:00.000Z",
  "entryCount": 1,
  "entries": [
    {
      "id": "5b8d0f2c-7d2a-4f6e-9b1a-2c3d4e5f6071",
      "dreamDate": "2026-05-18",
      "body": "free text, may be multi-line",
      "isLucid": false,
      "createdAt": "2026-05-19T08:00:00.000Z",
      "updatedAt": "2026-05-19T08:00:00.000Z"
    }
  ]
}
```

- `exportedAt`, `createdAt`, `updatedAt`: UTC ISO-8601 instants.
- `dreamDate`: local calendar day, `yyyy-MM-dd` (dreams are day-granular).
- Soft-deleted (tombstoned) entries are not exported.
- JSON import is not implemented yet; the schema is versioned so a future
  importer can evolve safely.
