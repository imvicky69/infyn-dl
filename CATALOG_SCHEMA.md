# Infyn DL - Playlist Catalog Schema & Contribution Guide

Infyn DL supports an open, community-curated playlist catalog hosted directly on GitHub. The catalog is statically served over GitHub Raw, completely anonymous, and requires zero user accounts or backend infrastructure.

---

## 1. Catalog JSON Schema

The catalog file [`catalog/playlists.json`](file:///c:/Users/rajvi/Repo/media_downloader/catalog/playlists.json) contains a list of verified YouTube & YouTube Music playlists.

### TypeScript Definition
```typescript
interface PlaylistCatalog {
  $schema?: string;
  version: number;
  updatedAt: string; // ISO 8601 Timestamp
  playlists: CatalogPlaylist[];
}

interface CatalogPlaylist {
  /** Unique snake_case identifier (e.g. "lofi_study_chill") */
  id: string;

  /** Display title shown in the app feed */
  title: string;

  /** 
   * Complete playlist URL from YouTube or YouTube Music.
   * e.g. "https://music.youtube.com/playlist?list=PLOzDu-MXXL3jkZ5v4_7g_XjBqP4Wj3k3m"
   * or "https://www.youtube.com/playlist?list=PLDcnymzs18LWrKzHmzrGH1JzLBqrH3xQ1"
   */
  url: string;

  /** A short 1-2 sentence description */
  description?: string;

  /** Primary musical genres (e.g. ["Lo-Fi", "Pop", "Rock"]) */
  genres: string[];

  /** Primary languages of vocals or "Instrumental" (e.g. ["English", "Hindi"]) */
  languages: string[];

  /** Intended listening context or vibe (e.g. ["Focus", "Chill", "Workout"]) */
  moods: string[];

  /** Search keywords and tag associations */
  tags?: string[];

  /** Whether to highlight this playlist in the Featured section */
  featured?: boolean;

  /** Direct HTTPS image URL for high-resolution cover artwork */
  thumbnailUrl?: string;

  /** Approximate number of tracks in the playlist */
  trackCount?: number;

  /** Curator, artist, or channel name */
  author?: string;
}
```

---

## 2. Example Entries

### YouTube Music Playlist:
```json
{
  "id": "lofi_study_chill",
  "title": "Lofi Beats to Relax / Study to",
  "url": "https://music.youtube.com/playlist?list=PLOzDu-MXXL3jkZ5v4_7g_XjBqP4Wj3k3m",
  "description": "Chill beats, peaceful melodies, and soothing lofi vibes for studying, reading, and deep focus.",
  "genres": ["Lo-Fi", "Chillhop", "Instrumental"],
  "languages": ["Instrumental", "English"],
  "moods": ["Focus", "Chill", "Relax"],
  "tags": ["study", "work", "sleep", "chill", "peaceful"],
  "featured": true,
  "thumbnailUrl": "https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&auto=format&fit=crop&q=80",
  "trackCount": 30,
  "author": "Lofi Girl"
}
```

### YouTube Standard Playlist:
```json
{
  "id": "today_top_hits",
  "title": "Today's Top Hits & Pop Anthems",
  "url": "https://www.youtube.com/playlist?list=PLDcnymzs18LWrKzHmzrGH1JzLBqrH3xQ1",
  "description": "The hottest music from across the globe right now. Catchy hooks, upbeat rhythms, and chart toppers.",
  "genres": ["Pop", "Dance", "R&B"],
  "languages": ["English"],
  "moods": ["Party", "Workout", "Energy"],
  "tags": ["pop", "chart", "hits", "trending", "dance"],
  "featured": true,
  "thumbnailUrl": "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80",
  "trackCount": 25,
  "author": "Pop Central"
}
```

---

## 3. Standard Vocabulary Guidelines

### Standard Languages
`English`, `Hindi`, `Punjabi`, `Spanish`, `Korean`, `Japanese`, `Instrumental`, `Arabic`, `French`, `German`, `Tamil`, `Telugu`, `Bengali`, `Portuguese`

### Standard Genres
`Pop`, `Lo-Fi`, `Hip-Hop`, `Rock`, `Electronic`, `Classical`, `R&B`, `Acoustic`, `Indie`, `Bollywood`, `Jazz`, `Folk`, `Ambient`, `Metal`, `K-Pop`, `Latin`, `City Pop`

### Standard Moods
`Chill`, `Focus`, `Workout`, `Party`, `Sleep`, `Commute`, `Romantic`, `Energy`, `Relax`

---

## 4. How to Submit a New Playlist

1. **Fork** the repository: [imvicky69/infyn-dl](https://github.com/imvicky69/infyn-dl).
2. Copy the complete URL of the public playlist from YouTube or YouTube Music.
3. Append your playlist entry to [`catalog/playlists.json`](file:///c:/Users/rajvi/Repo/media_downloader/catalog/playlists.json).
4. Open a **Pull Request**. Once merged, all Infyn DL apps automatically discover your playlist on their next background catalog refresh!
