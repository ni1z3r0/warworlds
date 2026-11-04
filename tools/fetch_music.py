#!/usr/bin/env python3
"""Download the game's music from the Musopen Kickstarter recordings on
archive.org (Czech National Symphony Orchestra, released to the public
domain by Musopen in 2012) and cut each into a looping excerpt.

    python3 tools/fetch_music.py            # writes audio/music/*.ogg

Needs network access to archive.org and *.archive.org, plus ffmpeg.
"""
import os
import subprocess
import sys
import urllib.parse
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "audio", "music")
CACHE = os.environ.get("MUSIC_CACHE", "/tmp/musopen_cache")
ZIP = "https://archive.org/download/musopen-dvd/Musopen-DVD.zip/"

# id: (path inside the Musopen DVD, start seconds, length seconds, why)
TRACKS = {
    "tragic_overture": ("Brahms - Tragic Overture/Tragic Overture.mp3", 0, 230,
                        "Menu: the storm about to break."),
    "la_malinconia": ("String Quartets/Beethoven String Quartet in B flat Major Op 18/"
                      "String Quartet No. 6 in B Flat Major, Op. 18, No. 6 - IV. (Adagio) La Malinconia.mp3", 0, 200,
                      "The storybook: Beethoven's 'Melancholy'."),
    "scottish_andante": ("Mendelssohn - Scottish Symphony/Symphony No. 3 in A Minor Scottish, Op. 56 - I. Andante con moto.mp3", 0, 190,
                         "I. The Eve of the War: night at the observatory."),
    "steppes": ("Borodin - In The Steppes Of Central Asia/In The Steppes of Central Asia.mp3", 0, 230,
                "II. The Falling Star: a still dawn and something coming."),
    "american_lento": ("String Quartets/Dvorak - American in F major/"
                       "String Quartet No. 12 in F Major, Op. 96, American - II. Lento.mp3", 0, 220,
                       "III. On Horsell Common: a summer crowd, uneasy."),
    "pathetique_adagio": ("Tchaikovsky - Symphony Pathetique/"
                          "Symphony No. 6 In B Minor, Op. 74, 'Pathetique' - I. Adagio, Allegro Non Troppo.mp3", 0, 230,
                          "IV. The Cylinder Opens: darkness rising from the pit."),
    "coriolan": ("Beethoven - Coriolan Overture/Coriolan Overture.mp3", 0, 230,
                 "V. The Heat-Ray: hammer blows."),
    "mozart_40": ("Mozart - Symphony No 40 in G Minor /1st Mov Molto allegro.mp3", 0, 210,
                  "VII. How I Reached Home: the flight in the dusk."),
    "egmont": ("Beethoven - Egmont Overture Op. 84/Egmont Overture Op. 84.mp3", 0, 230,
               "IX. The Fighting Begins: defiance."),
    "brahms_1": ("Brahms - Symphony No 1 in C Major/"
                 "Symphony No. 1 in C Minor, Op. 68 - I. Un poco sostenuto - Allegro.mp3", 0, 230,
                 "X. In the Storm: the pounding timpani."),
    "marcia_funebre": ("Beethoven - Symphony No 3 Eroica/"
                       "Symphony No. 3 in E Flat Major Eroica, Op. 55 - II. Marcia funebre Adagio assai.mp3", 0, 230,
                       "XI. At the Window: dawn over the dead."),
    "pathetique_march": ("Tchaikovsky - Symphony Pathetique/"
                         "Symphony No. 6 in B minor, Op. 74, 'Pathetique' - III. Allegro molto vivace.mp3", 300, 230,
                         "XII. Weybridge and Shepperton: the relentless march."),
    "mountain_king": ("Grieg - Peer Gynt/Peer Gynt Suite No. 1, Op. 46 - IV. In the Hall Of The Mountain King.mp3", 0, 150,
                      "Interlude: the Martian at the controls."),
    "suk_meditation": ("String Quartets/Suk -Meditation/Meditation.mp3", 0, 220,
                       "XIII. The Curate: a meditation on an old chorale."),
    "mendelssohn_80": ("String Quartets/Mendelssohn Quartet in F Minor Op 80/"
                       "String Quartet No. 6 in F minor, Op. 80 - I. Allegro vivace assai.mp3", 0, 220,
                       "XIV-XVI. The Exodus: panic in F minor."),
    "hebrides": ("Mendelssohn - Hebrides/Hebrides Overture Fingal's Cave.mp3", 0, 230,
                 "XVII. The Thunder Child: the sea."),
    "pathetique_finale": ("Tchaikovsky - Symphony Pathetique/"
                          "Symphony No. 6 in B minor, Op. 74, 'Pathetique' - IV. Finale Adagio lamentoso.mp3", 0, 230,
                          "The Ruined House: fifteen days of dread."),
    "brahms_4": ("Brahms - Symphony No 4 in E minor/Symphony No. 4 in E Minor, Op. 98 - I. Allegro Non Troppo.mp3", 0, 230,
                 "VII. The Man on Putney Hill: grand plans in a ruined world."),
    "aases_death": ("Grieg - Peer Gynt/Peer Gynt Suite No. 1, Op. 46 - II. Aase's Death.mp3", 0, 270,
                    "VIII. Dead London: the last 'Ulla' fades."),
    "morning": ("Grieg - Peer Gynt/Peer Gynt Suite No. 1, Op. 46 - I. Morning.mp3", 0, 230,
                "IX-X. The Epilogue, and every victory: dawn after the Martians."),
}


def fetch(path):
    os.makedirs(CACHE, exist_ok=True)
    local = os.path.join(CACHE, os.path.basename(path))
    if os.path.exists(local) and os.path.getsize(local) > 100000:
        return local
    url = ZIP + urllib.parse.quote("Musopen DVD/" + path)
    print("  downloading", os.path.basename(path))
    with urllib.request.urlopen(url, timeout=300) as r, open(local + ".part", "wb") as f:
        while True:
            b = r.read(1 << 20)
            if not b:
                break
            f.write(b)
    os.replace(local + ".part", local)
    return local


def cut(src, dst, start, length):
    fade_out = 8
    af = (f"loudnorm=I=-20:TP=-2:LRA=14,"
          f"afade=t=in:st=0:d=3,afade=t=out:st={length - fade_out}:d={fade_out}")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", str(start), "-t", str(length), "-i", src,
                    "-af", af, "-ar", "44100", "-ac", "2", "-c:a", "libvorbis", "-q:a", "1", dst], check=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])
    for tid, (path, start, length, why) in TRACKS.items():
        if only and tid not in only:
            continue
        src = fetch(path)
        dst = os.path.join(OUT, tid + ".ogg")
        cut(src, dst, start, length)
        print(f"  {tid:20s} {os.path.getsize(dst) // 1024:5d} KB  {why}")
