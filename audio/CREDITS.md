# Audio credits

## Music: `audio/music/`

All music comes from the **Musopen Kickstarter recordings** (2012), played by the
**Czech National Symphony Orchestra** and its string players. Musopen paid for the
recordings and released them into the **public domain** (Creative Commons
Public Domain Mark / CC0). The compositions are long out of copyright too.

- Source: <https://archive.org/details/musopen-dvd> (Internet Archive mirror of musopen.org)
- Licence: <https://creativecommons.org/publicdomain/mark/1.0/>

Each file is an excerpt of about 3 to 4½ minutes, with fades so it loops. The
volume is normalised. `tools/fetch_music.py` rebuilds them all.

| File | Piece | Where it plays |
|---|---|---|
| tragic_overture | Brahms, *Tragic Overture*, Op. 81 | Main menu |
| la_malinconia | Beethoven, String Quartet Op. 18 No. 6, IV "La Malinconia" | The storybook |
| scottish_andante | Mendelssohn, Symphony No. 3 "Scottish", I | I. The Eve of the War |
| steppes | Borodin, *In the Steppes of Central Asia* | II. The Falling Star |
| american_lento | Dvořák, String Quartet No. 12 "American", II Lento | III. On Horsell Common |
| pathetique_adagio | Tchaikovsky, Symphony No. 6 "Pathétique", I | IV. The Cylinder Opens |
| coriolan | Beethoven, *Coriolan Overture* | V–VI. The Heat-Ray |
| mozart_40 | Mozart, Symphony No. 40, I | VII–VIII. How I Reached Home |
| egmont | Beethoven, *Egmont Overture* | IX. The Fighting Begins |
| brahms_1 | Brahms, Symphony No. 1, I | X. In the Storm |
| marcia_funebre | Beethoven, Symphony No. 3 "Eroica", II Marcia funebre | XI. At the Window |
| pathetique_march | Tchaikovsky, Symphony No. 6, III | XII. Weybridge and Shepperton |
| mountain_king | Grieg, *Peer Gynt*, "In the Hall of the Mountain King" | Interlude: The Martian |
| suk_meditation | Suk, *Meditation on the Old Czech Chorale "St Wenceslas"* | XIII. The Curate |
| mendelssohn_80 | Mendelssohn, String Quartet No. 6, Op. 80, I | XIV–XVI. The Exodus |
| hebrides | Mendelssohn, *The Hebrides* | XVII. The Thunder Child |
| pathetique_finale | Tchaikovsky, Symphony No. 6, IV Adagio lamentoso | Book Two: The Ruined House |
| brahms_4 | Brahms, Symphony No. 4, I | VII. The Man on Putney Hill |
| aases_death | Grieg, *Peer Gynt*, "Åse's Death" | VIII. Dead London |
| morning | Grieg, *Peer Gynt*, "Morning Mood" | IX–X. The Epilogue |

## Sound effects: `audio/sfx/`

Every sound effect is **synthesised from scratch** by `tools/gen_sfx.py`, using
noise, oscillators and envelopes, with no recorded samples. They are original to
this project and are covered by its licence. Among them: the Martians' "Ulla"
howl, the Heat-Ray, the fighting-machines' strides, the cylinder unscrewing,
field guns, thunder and rain, crowds, and footsteps.
