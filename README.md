<h1 align="center">XS-TaxiJob</h1>

<p align="center">A civilian taxi job for <strong>QBox</strong> and <strong>QBCore</strong>: a driver tablet, a live meter, NPC and player fares, depots you build in game, and a reputation ladder.</p>

<p align="center">
  <a href="https://github.com/XyraL/XS-TaxiJob/releases"><img src="https://img.shields.io/github/v/release/XyraL/XS-TaxiJob?style=flat-square&color=f5bb55&label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/framework-QBox%20%7C%20QBCore-55dcff?style=flat-square" alt="framework">
  <img src="https://img.shields.io/badge/price-free-30d158?style=flat-square" alt="price">
  <a href="https://xyralscripts.dev/docs-xs-taxijob"><img src="https://img.shields.io/badge/docs-xyralscripts.dev-a889ff?style=flat-square" alt="docs"></a>
  <a href="https://discord.gg/XRURAw4TM2"><img src="https://img.shields.io/badge/support-discord-5865F2?style=flat-square" alt="support"></a>
</p>

<p align="center">
  <a href="https://xyralscripts.dev/xs-taxijob">Website</a> &nbsp;·&nbsp;
  <a href="https://xyralscripts.dev/docs-xs-taxijob">Setup guide</a> &nbsp;·&nbsp;
  <a href="https://github.com/XyraL/XS-TaxiJob/releases">Releases</a> &nbsp;·&nbsp;
  <a href="https://discord.gg/XRURAw4TM2">Discord</a>
</p>

---

## What it is

Sign on at a depot, take a cab against a deposit (or drive your own car where
the depot allows it), and run fares. The meter starts when someone gets in and
runs on distance plus waiting time. How you drive sets the tip, the tip feeds
reputation, and reputation unlocks better cabs and a bigger cut of every fare.

Anyone can drive unless you set a job for it.

## Three ways to get work

**Put the lamp on and drive.** People on the pavement flag the cab down. The
one waving gets a flashing blip on your map and a marker over their head, and
you're told which side of the road they're on. Pull over and they get in. `/lamp`
turns it off.

**Find a fare.** Dispatch sends a pickup anywhere on the road network, with a
drop-off across town. The passenger is waiting at the kerb when you get there.

**Someone calls a cab.** A player calls from their phone or types `/taxi`, and
every driver with the lamp on gets the call on the tablet and their phone. The
first to accept takes it. There's no set destination: the meter runs until you
end the ride where they asked to go.

## The driver tablet

Press **F6** or type `/cab`. On shift it opens anywhere. Off shift it opens at
a depot, and anywhere else it sets your GPS to the nearest one.

- **Calls**: player calls on a map, with accept and pass
- **Fare**: the live meter and the job you're on
- **Shift**: sign on and off, the lamp, time and takings
- **Earnings**, **Record**, **Cabs** and the **Board** (leaderboard)

Staff with the admin ace also get **Drivers**, **Dispatch** and **Depots**.

## Depots

Build them in game. Open the tablet as an admin, go to **Depots** and make a
new one:

- Stand where the dispatcher should be and set the desk
- Park where cabs should appear and add a bay (up to 16)
- Pick the blip icon, colour and size
- Choose which cabs it rents, and if it needs a job
- Turn on **Own cars** to let drivers use a car they own

Changes reach every player straight away. The first depot comes from
`Config.Depot.first` the first time the script starts. After that, edit it in
game.

## Own cars

At a depot with **Own cars** on, a driver can sign on in a car registered to
them. They have to be in the driver's seat, and it has to be a car (no bikes).
There's no deposit to pay and none to get back. `Config.PersonalVehicles`
sets the fare rate and your vehicles table if it isn't `player_vehicles`.

## Phones

Found on their own. Nothing to set up.

| Phone | What you get |
| ----- | ------------ |
| XS-Phone | Call a cab card in the Services app, and call alerts for drivers |
| lb-phone | Taxi app, texts to the `taxi` company call a cab, alerts |
| qs-smartphone, qs-smartphone-pro | Taxi app, alerts |
| gksphone | Taxi app, messages to the `taxi` service call a cab, alerts |
| yseries, okokPhone | Taxi app, alerts |
| npwd | Call or text 555-8294 to call a cab, alerts |
| high-phone, roadphone, 17mov_Phone, qb-phone | Alerts |

The Taxi app shows how many cabs are free, then who took your call and their
plate. `Config.Phones` sets the app name, the company and the number.

## Uniforms

`Config.Uniform.enabled` puts drivers in cab company clothes for the shift and
gives their own clothes back when they sign off. Put the component numbers in
`Config.Uniform.male` and `.female`, or set `useExport` to hand it to your own
appearance script (it needs `SetTaxiUniform(outfit)` and `ClearTaxiUniform()`).

## Admin

Grant `Config.AdminAce` (default `xstaxi.admin`) to see the admin pages. Every
action checks the ace again on the server.

- **Drivers**: who's signed on, their car, fare and takings. Adjust standing,
  clear a stuck fare, end a shift or wipe a driver's record
- **Dispatch**: pause dispatch, allow player calls, and a fare multiplier for
  events. These reset on restart
- **Pay & rates**: the meter, night and cross-town rates, the deposit, tips
  by rating, and each cab's rate and tier's bonus. Saved, and they start on
  the next fare. **Use config.lua** puts the config values back
- **Depots**: the builder above

## Requirements

- `ox_lib`
- `oxmysql`
- `qbx_core` or `qb-core`

## Install

1. Drop the `XS-TaxiJob` folder into your `resources`.
2. Add `ensure XS-TaxiJob` to your `server.cfg`, after ox_lib, oxmysql, your
   framework and your keys script.
3. Grant the admin ace:
   ```
   add_ace group.admin xstaxi.admin allow
   ```

No SQL to import. The tables create themselves on first start.

## Updating from 1.x

Replace the whole folder, **config.lua included**, since 2.0 adds new settings.
Your drivers, reputation and fare history stay. Your depot is created from the
new config the first time it starts, then you edit it in game.

## How a shift runs

1. Go to a depot and open the tablet.
2. Rent a cab, or sign on in your own car if the depot allows it.
3. Turn the lamp on, find a fare, or wait for a call.
4. Stop at the pickup. The passenger gets in and the meter starts.
5. Drop them off and get paid.
6. Park a rented cab in any depot's bay and sign off to get the deposit back.
   Damage comes off it.

## Rating and reputation

Every fare starts at five stars. You lose them for hitting things, flooring
it, flipping the cab or hurting your passenger. The stars set the tip:

| Stars | Tip |
| ----- | --- |
| 5 | 25% |
| 4 | 15% |
| 3 | 7% |
| 2 or 1 | nothing |

Reputation comes off the same rating. Tiers unlock cabs and raise every fare:

| Tier | Rep | Cab unlocked | Fare bonus |
| ---- | --- | ------------ | ---------- |
| Trainee | 0 | Taxi | none |
| Driver | 40 | Stanier | +8% |
| Veteran | 140 | Primo Custom | +16% |
| Elite | 320 | Baller | +25% |
| Legend | 650 | Stretch | +35% |

These are the defaults. Change tips, cab rates and tier bonuses in game under
**Pay & rates**.

## Commands

| Command | Who | What |
| ------- | --- | ---- |
| `/cab` (F6) | anyone | Open the driver tablet. |
| `/lamp` | driver | Turn the roof lamp on or off. |
| `/taxi` | anyone | Call a cab to where you're standing. |
| `/canceltaxi` | anyone | Cancel your call. |
| `/endride` | driver | End a called ride and take payment. |
| `/accepthail [id]` | driver | Accept a call without opening the tablet. |
| `/taxistats` | driver | Your tier, reputation, fares and rating. |
| `/taxirep <id> <n>` | admin | Adjust a driver's reputation. |
| `/taxiendshift <id>` | admin | End a driver's shift. |

## Works with

Found on their own. The job runs without any of them.

- **Vehicle keys**: qbx_vehiclekeys, Renewed-Vehiclekeys, wasabi_carlock,
  mk_vehiclekeys, jaksam's vehicles_keys, qs-vehiclekeys, qb-vehiclekeys,
  cd_garage and okokGarage
- **Fuel**: cdn-fuel, ps-fuel, lc_fuel, lj-fuel, qb-fuel, Renewed-Fuel,
  okokGasStation, ti_fuel, BigDaddy-Fuel, x-fuel, rcore_fuel, qs-fuelstations,
  ND_Fuel, melons_fuel, LegacyFuel and ox_fuel. Cabs leave the depot full
- **Target**: ox_target or qb-target to talk to the dispatcher. Without one
  it's a marker and an E prompt
- **Phones**: see Phones above

## Exports

```lua
-- server
exports['XS-TaxiJob']:IsDriverOnDuty(source)    -- boolean
exports['XS-TaxiJob']:GetDriverSummary(source)  -- tier, rep, rating, totals
exports['XS-TaxiJob']:RequestRide(source)       -- call a cab for a player
exports['XS-TaxiJob']:CancelRide(source)
exports['XS-TaxiJob']:GetRideStatus(source)     -- none, waiting, accepted or riding
exports['XS-TaxiJob']:GetFreeDrivers()
exports['XS-TaxiJob']:GetDriversOnShift()
exports['XS-TaxiJob']:GetLocations()            -- every depot
```
