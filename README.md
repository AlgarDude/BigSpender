# BigSpender

Addon that spends merit points, job points and trust points from the command line, with an optional autospend. Supports custom priority lists, if desired.

Use at your own risk.\
Sends packets directly instead of using the menus. Roughly mimics standard purchasing speed (Unless you have ten thumbs and no rhythm, then this one may be faster).
Spending outside of a Mog House is not only unnatural, it may be visible to others... they may notice your held merit or job point totals change from log lines when you gain one.

Known issue: Merits are only sent on login/zone. You must zone if you (re)start this script after login and wish to purchase merits.

## Commands

```
//spend merits buy <merit>                      buy one rank of <merit>
//spend merits spendnow [amount]                spend down your (or the default) priority list
//spend merits preview [amount]                 show what spendnow would buy
//spend merits autospend [on | off | points]    spend at the merit cap (75) or at points

//spend jp buy [job] <point name>               buy one rank of <point name>
//spend jp spendnow [job | all] [amount]        buys your priority list until maxed, then the rest
//spend jp preview [job | all] [amount]         show what spendnow would buy
//spend jp autospend [on | off | points]        spend at the JP cap (500, main job only) or at points

//spend trust buy <upgrade>                     buy one rank of <upgrade>
//spend trust spendnow [amount]                 buys your priority list until maxed, then the rest
//spend trust preview [amount]                  show what spendnow would buy

//spend stop                                    stop after the current raise
//spend debug [on | off]                        log to data/debug_<name>.log
//spend help
```
Examples:

```
//spend merits buy max h                        buy one rank of Max HP
//spend merits spendnow 20                      spend up to 20 merit points
//spend jp buy pld invincible                   buy one rank of PLD Invincible Effect
//spend jp spendnow geo 100                     spend up to 100 GEO job points
//spend jp spendnow all                         spend job points on every job
//spend jp autospend 300                        spend automatically at 300 instead of the cap
//spend trust buy magic                         buy one rank of Magic Skills
```

## Settings

`data/settings.xml` is created on first load. Reload the addon after editing it.

- `meritPriority`: full merit names in order. `Magic Skills`, `Combat Skills` and `Attributes` cover the whole group. Max MP is skipped on jobs without MP.
- `jpPriority`: a list per job. Anything not listed gets bought cheapest first, once everything listed is maxed.
- `trustPriority`: same, for alter ego upgrades.
- `debug`: turns the debug log on at load.

```xml
<settings>
    <global>
        <meritPriority>Maximum Merit Points,Max HP,Max MP,Magic Skills,Combat Skills,Attributes</meritPriority>
        <jpPriority>
            <PLD>Invincible Effect,Sentinel Effect</PLD> <!-- example only -->
        </jpPriority>
        <trustPriority>HP,Magic Skills</trustPriority> <!-- example only -->
    </global>
    <yourname> <!-- example only -->
        <meritPriority>Critical Hit Rate,Max HP,Max MP</meritPriority>
    </yourname>
</settings>
```

For per-character settings, add a block named after the character next to `<global>`.

## Install

Extract to `Windower/addons/BigSpender/` (rename the folder if the zip gave you `BigSpender-main`), then `//lua load bigspender`.

## License

GPL-3.0. See [LICENSE](LICENSE).
