# Changelog

## 1.2.0

The 1.1.0 work never shipped. This is that, plus what was wrong with it.

### Fixed

- **The admin panel looked like it was never installed.** The Admin tab was
  hidden on every open of the terminal. `OpenTerminal` forwards the server's
  state table straight to the page, and `isAdmin` was only ever attached on
  the other path — the getState callback — so the page saw `undefined` and
  re-hid the tab. The only thing that calls refresh is a shift button, which
  an off-duty admin does not have, so there was no way back to it. The server
  sends the flag now, so both paths agree.
- **A hailed ride could not be ended from the terminal.** A player hail has no
  destination: the driver is told to end it where the passenger asks, and the
  only thing that could do that was the `/endride` command, which nothing
  mentions. There was no button because the state never said a hailed ride was
  running. Both are fixed.
- **The deposit was whatever the client said it was.** The server asked the
  client whether the cab had been parked up and how bent it was — the one
  question a client has a reason to lie about. It is worked out here now, from
  the cab.
- **`Config.Fares.offerTimeout` was multiplied by six and used as the deadline
  to reach the pickup**, while the config line said it governed accepting an
  offer. Lowering it to make offers expire faster instead made most fares
  impossible. It is `pickupTimeout`, in seconds, and it means what it says.
- **The night bonus ran on two different clocks.** The payout read the host
  machine's wall clock; the dash read the in-game hour. For most of a real day
  the driver watched the meter promise 25% the payout did not honour. The
  server decides it once when it builds the fare and sends it down with it.
- **A cab sometimes would not start.** The server asked for the entity the
  instant its net id arrived, before it had replicated, and gave up silently
  when it was not there yet — so the keys handoff worked or did not depending
  on server load. It waits now, and says so if it never arrives.
- **`/taxi` did nothing at all when an admin paused dispatch** — no message,
  no error. A command handler's return value goes nowhere.
- **The Shift tab still advertised hailing after an admin switched it off.**
  getState read the config flag and ignored the live switch.
- **A cab could be left in the bay forever.** Deleting an entity you do not own
  does nothing, and the cab is migratable, so another player standing near it
  was enough. Control is requested first.
- **The uniform never came back after a respawn.** The repair event existed and
  nothing ever fired it.
- **"An admin ended your shift" was shown whether it ended or not**, twice, and
  in two different colours.
- **The meter's status dot never lit.** It toggled `live` and `idle`; the
  stylesheet styles `running`.
- **Every fare popup after a sign-off was titled "Shift over."**
- **The Rep button in the admin panel did nothing.** `prompt()` is inert in
  FiveM's CEF. It is a +10 / -10 pair now.
- Record and Board rendered as unstyled browser tables, the cab roster had no
  layout rule at all, and the headline number on both summary cards was styled
  like the rows above it.
- `Framework.GetName` returned two values — the name and the number of
  replacements `gsub` made. Every call site truncated it, so this was a
  landmine rather than a fault.
- Removed a second way to ask for the leaderboard that nothing used; getState
  has carried it all along.

### Added

- **`tools/`** — nine checkers covering the manifest, event and NUI wiring,
  config keys, multi-return leaks, net-id guards, runtime split, native names
  and Lua syntax. `node tools/check-all.mjs`. The dead end-ride endpoint is
  what they found first.

## 1.1.0

### Added

- **Admin panel.** A staff-only tab in the terminal showing everyone signed on,
  what they are driving, the fare they are running, what they have taken and
  where they stand. Per driver you can adjust standing, clear a stuck fare or
  end their shift. Three live switches — pause dispatch, allow hailing, fare
  multiplier — hold until the next restart, then config.lua takes over again.
  They are for handling a situation now, not for tuning the server.
- **Uniforms.** `Config.Uniform` puts drivers in cab company kit while they are
  signed on and gives them their own clothes back when they sign off. Off by
  default. It sets clothing components directly, so it needs no appearance
  resource; a server that already has one can point `useExport` at it instead
  and the components are used only if that export is missing or errors.

### Changed

- The terminal was restyled: display type, animated panels, tiles that carry
  their own accent, a lit roof lamp on the header, and a meter that reads like
  a meter. The stylesheet now covers both its own class names and the ones the
  panels were already written against, so no panel had to be rewritten.
- The depot moved to the coordinates from the server, with four cab bays.

### Fixed

- The meter and any hail cards no longer sit on top of the terminal. They were
  covering the bottom-right corner, which is where the buttons are.

## [1.0.0] - 2026-09-10

First build.

### Added

- Depot terminal with a cab roster, shift stats, personal record and a company board
- Rented cabs against a deposit, with damage taken off the refund on return
- Live meter: flagfall, distance, waiting time, night rates and a cross-town bonus
- NPC fares pulled from a config point list, grouped by area and gated by tier
- Player fares — `/taxi` calls every signed-on driver in range, first to accept takes it
- Open-ended hailed rides that the driver ends with `/endride` wherever the passenger asked for
- Ride ratings that fall for collisions, speeding, flipping the cab and hurting the passenger
- Tips and reputation both scale off the rating, so driving well is the progression
- Five reputation tiers unlocking cabs and raising the fare multiplier
- Bridges for framework, target, vehicle keys and XS-Phone, all auto-detected and all optional
- Server-side fare validation: the client's meter is a ceiling, never the source of truth
