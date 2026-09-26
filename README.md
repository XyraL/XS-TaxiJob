<h1 align="center">XS-TaxiJob</h1>

<p align="center">A civilian taxi job for <strong>QBox</strong> and <strong>QBCore</strong> — live meter, NPC and player fares, ride ratings and a reputation ladder.</p>

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

<!-- SCREENSHOTS: drop 2-3 in-game shots here once captured -->

---

## What it is

Talk to the dispatcher, take a cab against a deposit, and run fares. The meter
starts when someone gets in and runs on distance plus waiting time. How you
drive sets the tip, the tip feeds reputation, and reputation unlocks better
cabs and a bigger cut of every fare.

No whitelist. Anyone can drive.


## Three ways to get work

**Put the lamp on and drive.** People on the pavement flag the cab down as you
pass. Pull over and they get in; drive on and they do not. `/lamp` turns it off
when you are heading back to the depot and would rather not be stopped.

**Call dispatch.** A pickup anywhere on the road network, with a drop-off the
other side of it. The passenger is stood at the kerb by the time you get there
and walks to the cab rather than waiting for you to park on the marker.

**Someone rings for a cab.** A player types `/taxi` and every driver with a
lamp on gets the call. First to take it gets it. That one is open-ended — no
destination, the meter runs until you end the ride where they ask.


## Uniforms

`Config.Uniform.enabled` puts drivers in cab company kit for the length of a
shift and hands their own clothes back when they sign off.

It writes clothing components straight onto the ped, so there is no appearance
resource to install and nothing to keep in sync. Build the outfit you want on a
character with your clothing menu, read the component numbers off it, and put
them in `Config.Uniform.male` / `.female`.

If you would rather your own appearance resource handled it, set
`useExport = true` and `exportResource` to its name. It needs to export
`SetTaxiUniform(outfit)` and `ClearTaxiUniform()`. If either is missing or
throws, the components are used instead, so a broken export downgrades rather
than leaving someone half-dressed.

## The terminal

`/cab` opens it from wherever you are. At the depot anyone can use it; away
from it you have to be signed on, so the cab has a terminal in it without the
depot becoming something you can skip. Put a key in `Config.Depot.key` if you
want one, or bind it yourself under Settings, Key Bindings, FiveM.

## Admin

Grant `Config.AdminAce` (default `xstaxi.admin`) and an **Admin** tab appears
in the terminal. Nobody else can see it, and every callback behind it checks the
ace again on the server — the hidden tab is a convenience, not the security.

It shows who is signed on, what they are driving, the fare they are running and
what they have taken this shift, plus all-time payout across the server. Per
driver: adjust standing, clear a fare that has got stuck, or end their shift.

The three switches at the top — pause dispatch, allow hailing, fare multiplier —
take effect immediately and are deliberately not saved. A restart puts the
server back to whatever config.lua says.

## Requirements

- `ox_lib`
- `oxmysql`
- Either `qbx_core` **or** `qb-core` — the bridge auto-detects which.
- `ox_target` or `qb-target` if you run one. The dispatcher at the depot is a
  ped you talk to, which needs one of them; without either it falls back to a
  marker and an E prompt on the same spot and the job works exactly the same.
- A vehicle-keys resource if your server runs one. `Config.Bridges.keys` is on
  `'auto'` and finds `qbx_vehiclekeys`, `qs-vehiclekeys` or `qb-vehiclekeys` by
  itself. Without this, the rented cab's engine will not start.

## Install

1. Drop the `XS-TaxiJob` folder into your `resources`.
2. **No SQL import needed.** The three tables create themselves on first start
   from `sql/install.sql`.
3. Add `ensure XS-TaxiJob` to your `server.cfg`, after ox_lib, oxmysql, your
   framework and your keys resource.
4. Grant the admin ACE if you want the staff commands:
   ```
   add_ace group.admin xstaxi.admin allow
   ```

## How a shift runs

1. Head to the Downtown Cab Co. blip and use the terminal.
2. Pick a cab from the roster. The deposit is held until you bring it back.
3. **Find a fare** from the terminal, or wait for someone to call one in.
4. Drive to the pickup and stop. The passenger gets in and the meter starts.
5. Take them where they are going. Stop at the drop-off and you get paid.
6. Park in a depot bay and sign off to get the deposit back. Damage comes off it.

## Fares

**NPC fares** are pulled from `Config.Fares.points`, grouped by area so a trip
across town is worth more than a lap of the block. Points are gated by tier, so
airport runs and county hauls open up as you climb.

**Player fares** work differently. Anyone can `/taxi` and the call goes out to
every signed-on driver in range; first to accept takes it. There is no set
destination — the meter runs from pickup until the driver ends it with
`/endride`, wherever the passenger asked to go. The passenger pays the meter.

## Rating and reputation

Every fare starts at five stars. You lose them for hitting things, sitting on
the throttle, flipping the cab, or getting your passenger hurt. The star rating
sets the tip:

| Stars | Tip |
| ----- | --- |
| 5 | 25% |
| 4 | 15% |
| 3 | 7% |
| 2 or 1 | nothing |

Reputation comes off the same rating, so a careful driver climbs roughly twice
as fast as a reckless one. Tiers unlock cabs and raise the multiplier on every
fare:

| Tier | Rep | Cab unlocked | Fare bonus |
| ---- | --- | ------------ | ---------- |
| Trainee | 0 | Taxi | — |
| Driver | 40 | Stanier | +8% |
| Veteran | 140 | Primo Custom | +16% |
| Elite | 320 | Baller | +25% |
| Legend | 650 | Stretch | +35% |

## Commands

| Command | Who | What |
| ------- | --- | ---- |
| `/taxi` | anyone | Call a cab to where you are standing. |
| `/endride` | driver | End an open-ended hailed ride and take payment. |
| `/accepthail [id]` | driver | Accept a waiting call. The id is optional with one call waiting. |
| `/taxistats` | driver | Your tier, reputation, fares and rating. |
| `/taxirep <id> <n>` | admin | Adjust a driver's reputation. |
| `/taxiendshift <id>` | admin | Force a driver off shift. |

## Config

Everything lives in `config.lua`: the depot and its cab bays, the roster and
what each cab pays, meter pricing, night rates, the penalty and tip tables, the
reputation ladder, and every pickup and drop-off point.

The pickup list ships with real Los Santos locations. Add your own by appending
to `Config.Fares.points` with an `area` and a `tier`.

## Integrations

Optional and auto-detected. Nothing here is required, and the job runs on its
own with none of it installed.

- **XS-Phone** — hail notifications reach the passenger's phone instead of a
  plain notification.
- **ox_target / qb-target** — the depot terminal. Falls back to a marker.
- **Vehicle keys** — see Requirements.

Two exports are available for your own scripts:

```lua
exports['XS-TaxiJob']:GetDriverSummary(source)  -- tier, rep, rating, totals
exports['XS-TaxiJob']:IsDriverOnDuty(source)    -- boolean
```
