# Steam Diving Bell

This is the source code to [Steam Diving Bell](https://www.fortressofdoors.com/steam-diving-bell/),
the prototype project that inspired [Steam Deep Dive](https://store.steampowered.com/labs/divingbell).

## License

All the code in this project is released under the MIT license. See LICENSE file for details.

The data files I'm linking I can't claim copyright for (and thus have no right to attach a specific license to) as they're scraped from Steam. Don't do anything dumb like pretend I'm giving you permission to "own" Portal 2's metadata or whatever.

I received Valve's written permission to release this project in this manner.

## Important Note

This source code is provided for research and archival purposes. All of my current
efforts are devoted to Deep Dive rather than Diving Bell, so regarding this repo:

- I am just releasing this source here, I'm not working on it actively
- I will probably not accept any pull requests
- I will probably not address bugs/feature requests

That said, it is entirely open source and you are more than well to fork it and 
use it for your own projects!

Also, if you have any questions about it I am happy to answer them when I have time.

## What it is

Diving Bell is a rough prototype of a discovery tool inspired by the 
"more like this" section on steam store pages. You start with a focused game
and it shows you 8 more games like that one, using a variety of recommendation
algorithms.

To see a live version:

[https://tools.fortressofdoors.com/steamdivingbell](https://tools.fortressofdoors.com/steamdivingbell)

To focus a specific app id:

Type "?appid=XYZ" (sans quotes) at the end of the URL above, and replace XYZ
with the appid of the game you want to see. Note that if the game was released
after the date the data for Diving Bell was scraped, you'll get an error because
it won't be in the data set.

See [this blog post](https://www.fortressofdoors.com/steam-diving-bell/) for more details.

## Diving Bell vs. Deep Dive: prototype vs. product

This is *not* the source code to Steam Deep Dive, a [Steam Labs](https://store.steampowered.com/labs) experiment
which remains the property of Valve corporation.

In this document the term "Diving Bell" refers exclusively to this prototype and 
the term "Deep Dive" refers exclusively to the official Steam Labs project.

## Build Instructions

This is an HTML5 project that depends on [Haxe](https://www.haxe.org) and 
[OpenFL](https://www.openfl.org).

The OpenFL dependency was introduced because I originally wanted to do some
fancy complex animations, but in the end I wound up simplifying everything to
a basic grid layout. When I went on to develop Deep Dive I rewrote the app from
scratch using a simple Haxe->JS pipeline.

In any case, to build Diving Bell after cloning this repo:

1. Install the [Haxe toolkit](https://haxe.org/download/) (I used version 3.4.7)
2. Install [OpenFL](https://www.openfl.org/download/) (use the Haxelib instructions)
3. Run "lime test html5" from the project's root directory

The bin/html5/bin folder should now contain index.html and dependent files.

4. Note that the "data" folder is pre-populated with all the scraped data that
Diving Bell needs to run, EXCEPT for these two directories:

```
/data/v2/app_details
/data/v2/img
```

You will need to populate these yourself. 

The missing files are here: 
[https://drive.google.com/open?id=1YoBZf-wUHk44RKAg6NzkmhV8JLXG_ji7](https://drive.google.com/open?id=1YoBZf-wUHk44RKAg6NzkmhV8JLXG_ji7)

And you can find them on my own site as long as the prototype stays up:
http://www.tools.fortressofdoors.com/steamdivingbell/data/v2/

(But please try the google drive link first so you don't hammer my server)

**Why isn't this data included?**

Because it's a huge amount of data and it makes git cry!

You see, I made some *questionable* design decisions throwing this rough 
prototype together, chief among them splitting app details out into *35,000+ 
individual files*. Same thing goes for app capsule images.

Now, a straight Haxe->JS image rewrite, or an OpenFL DOM target build, could 
probably get away with just directly hotlinking app capsule images from Steam 
URL's directly, but the way I wrote this app I try to load the bytes directly 
and display them in OpenFL Bitmap objects, which is the wrong way to do things 
if you don't want to run into CORS issues. So I just brute forced it by scraping 
all capsule images and dumping them into a folder. Needless to say, I used a 
much cleaner solution in Deep Dive.

In case the data links above ever goes dark, you will need to reproduce the 
data yourself.

`v2\app_details` includes a single file, `620.txt`, as an example of the 
necessary data format.

`v2\img` includes a single file, `620.jpg`, as an example of the necessary 
image format.

If and when my google drive link has gone dead, Steam's API's are likely
to have changed around enough to make specific scraping instructions useless;
It's not too hard to figure out and there's guides online in any case. And 
hopefully by then someone will have forked this repo to handle things in a much 
cleaner way so it's not even necessary anymore.

## Data overview

Diving Bell depends on a full scrape of (almost) every game on Steam. 
It's not using live data, the data I have was scraped sometime between 
June-July 2019 and IIRC overlapped the Steam Summer Sale.

Data is stored in `bin\html5\bin\data`, here's an overview:

```
\v1                     deprecated, no longer used
\v2                     all the data goes here
\v2\app_details\        JSON, individual details on each appid
\v2\img\                JPG, capsule images for each appid
\v2\more\               TSV, default "more like this" matches for each appid
\v2\more_noisy\         TSV, loose, 2nd-degree "more like this" matches for each appid
\v2\more_reverse\       TSV, reverse matches for each appid
\v2\reviews\raw.tsv     TSV, raw user review data for each appid (appid, #positive, #total)
\v2\reviews\gem.tsv     TSV, hidden gem score for each appid
\v2\reviews\top.tsv     TSV, weighted review score for each appid (takes uncertainty into account)
\v2\tags\tags.tsv       TSV, tag string id and tag label
\v2\tags\all.tsv        TSV, tags for each appid (numerical index is order they appear in tags.tsv -- this does NOT match Steam's internal tagid value!!!!)
\v2\tags\categories.tsv TSV, for each tag, what categories it belongs to (category scheme is one of my own invention, also its a bit out of date from a new classification scheme I'm using elsewhere)
\v2\tags\index          TSV, for each tag, which appids have that tag applied
\v2\games.txt           TSV, all appids for games I was able to scrape
\v2\titles.tsv          TSV, appid and title for every game I was able to scrape
```

## Key Differences from Deep Dive

- uses scraped, frozen data (new games won't show up)
- doesn't use any live algorithms, just tables outputted from running algorithms offline
- only shows 8 games rather than 9
- doesn't have search
- probably slower/jankier
- wishlist button doesn't actually work, it's just there for show
- not localized
- depends on OpenFL
- uses five recommenders instead of 3
  - Unique to Diving Bell:
    - Reverse: invert the more like this graph, so if I focus game X, then "reverse" recommendations would be games for which game X shows up in *their* "More Like This" list.
    - Loose: for game X, find 12 "more like this" matches, AND for each of *those*, their own 12 "more like this" matches, remove duplicates, return the result.
  - Also used in Deep Dive:
    - Default: just scrape Steam's "More Like This" page for game X and return the results
  - Similar to but different from Deep Dive:
    - Tags: find games with similar tags, but weigh tags using a category scheme. This is an *extremely* primitive version of Deep Dive's "keystone tag" matcher, which does a lot more stuff now.
    - Gems: find games with high "hidden gem" score, then sort those matches by tag similarity. Deep Dive calculates this in a similar but different way.
