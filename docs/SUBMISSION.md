# Project page text

Text for the fields of the NASA Space Apps project page. Each section is one form field; paste the text under the heading.

---

## Project Name
OrbitOrange

## High-Level Project Summary
OrbitOrange is a browser game in which the player runs a whole space mission, from the first choice to the final score. You pick a mission and the science it should do, build a rocket under a budget from 28 parts whose numbers come from NASA and other published sources, plan the launch and the engine burns on a real Keplerian orbit, and then fly the mission from a control room, where random events can force an emergency manoeuvre. The game answers the "Space Mission Design Game" challenge by keeping the real trade-offs connected: a better instrument is heavier, a heavier rocket needs more fuel, fuel costs money, and the orbit you reach decides how much science you deliver. Learning tools usually teach these topics one at a time; OrbitOrange lets a student feel how the decisions of a mission team depend on each other, and learn as much from a failed mission as from a successful one.

## Link to Project Demo
_(the video or slide deck link)_

## Link to Final Project
Play in the browser, nothing to install: https://ilayla.github.io/OrbitOrange/

Source code, documentation and the record of sources and AI use: https://github.com/IlayLa/OrbitOrange

## Detailed Project Description

**What it does**

A game of OrbitOrange has five steps:

1. **Choose the mission.** Each mission has a budget, a duration and a target orbit (for example, a 400 km circular low Earth orbit). The player then chooses the science (such as Earth imaging), which sets the altitude band where the instrument works and the amount of data to deliver, and may add optional quests that pay a grant or cost points.
2. **Build the rocket.** The player stacks stages from 28 parts in four groups: 7 engines (from a cold-gas thruster to a hydrogen upper-stage engine), 6 tank materials (aluminium, aluminium-lithium and composite, regulated or blowdown), 10 telemetry parts (altimeters, sun sensor, star tracker, fuel gauge, radars, onboard computers) and 5 science instruments (two Earth cameras, a magnetometer, an atmosphere probe and an imaging radar). Every part has a cost, a mass and a performance; a right-click shows where its numbers come from. Cost, delta-v and mass update as the rocket grows, and warning lamps say what stops a launch (for example, a liquid engine without a tank).
3. **Plan the flight.** The ascent is computed from the rocket and the launch angle the player chooses. On an orbit map the player then places engine pulses: press on the path, pull back to aim, and the predicted orbit (apoapsis, periapsis, eccentricity, period, remaining delta-v) updates at once.
4. **Fly the mission.** A control room plays the flight at up to 1000× speed. The instruments show only what the installed telemetry parts can measure, with their noise and limits; a reading with no sensor installed shows "NO SENSOR". Random events (a satellite conjunction, a debris shower, an unknown asteroid, a solar flare, an engine malfunction, a propellant leak, a sensor failure) can pause the flight and open an emergency screen where the player aims and sizes an avoiding burn, or ignores the threat.
5. **Get scored.** Orbit accuracy, budget, science delivered and quests add up to a score and a result, from Failure to Scientific Breakthrough. A flight log and a click on any score row explain where the points were lost, so the next attempt can be better.

**How it works**

- The orbits are real two-body (Keplerian) orbits, following the conventions of NASA Goddard's GMAT Mathematical Specifications: Kepler's equation for elliptic and hyperbolic orbits, impulsive burns, and the Earth's radius and gravitational parameter from the NASA Earth Fact Sheet and WGS 84.
- The rocket model uses the Tsiolkovsky rocket equation per stage, a lift-off thrust-to-weight check, and tank dry masses scaled from NASA's Space Shuttle External Tank figures.
- The part catalogue, the missions, the celestial bodies and the event types are plain JSON files, so a new part or mission is added without changing code.
- The flight simulation, the telemetry, the events and the scoring are separate modules with automatic tests, which the team runs with every scene before each change.

**Benefits**

- A student sees a whole mission as one system, not a list of separate topics.
- Every number in the catalogue is traceable to a public source, so the game teaches realistic orders of magnitude.
- Failure is part of the lesson: the score explains each lost point.
- It runs in any modern browser, with nothing to install.

**What we hope to achieve**

We want OrbitOrange to be a short, replayable lesson in systems thinking for students and aspiring engineers. Next, we would like to add more missions (rendezvous and docking, the Moon, the outer planets), unlock new parts as missions succeed, and add a mode where a team of players shares one mission.

**Tools**

- Godot Engine 4.7.2 and GDScript, exported to WebAssembly for the browser.
- JSON data files.
- GitHub, with GitHub Actions and GitHub Pages for the browser build.
- Pixel art drawn by the team.
- AI coding agents (Claude Code and OpenAI Codex) for most of the code, directed, tested and merged by the team.

## Use of Super Intelligence (SI)
Yes. Most of the game's code was written by AI coding agents, Claude Code (Anthropic; Claude Opus 5.5 and Claude Fable 5.2) and OpenAI Codex (GPT-6), working from a design and task contracts written by the team. Team members chose the idea, the game design and every feature, reviewed the agents' plans, tested the game, and merged each change. The agents also helped review the code and the design, and drafted documentation.

No image, sound or video in the game was made by AI: the sprites, portraits, screen mock-ups, logo and font are the team's own drawings, and the game has no sound. AI-written code is acknowledged in the repository: every working session (date, tool, model, request, files changed, human review) is recorded in `docs/AI_USAGE.md` and `docs/ai_usage/`, and AI-written commits carry a `Co-Authored-By` line.

## NASA Data
- **NASA, CubeSat 101: Basic Concepts and Processes for First-Time CubeSat Developers** (a resource of this challenge): the classes of the five science instruments. https://www.nasa.gov/wp-content/uploads/2017/03/nasa_csli_cubesat_101_508.pdf
- **NASA Small Spacecraft Systems Virtual Institute, State-of-the-Art of Small Spacecraft Technology**: the masses and accuracies of the GPS-class altimeters, sun sensor, star tracker and magnetometer (Guidance, Navigation and Control chapter), the cold-gas thruster (In-Space Propulsion chapter), and the onboard computers (Command and Data Handling chapter). https://www.nasa.gov/smallsat-institute/sst-soa/
- **NASA Goddard Space Flight Center, General Mission Analysis Tool (GMAT) Mathematical Specifications**: the orbit mathematics and conventions. https://ntrs.nasa.gov/citations/20080031744
- **NASA NSSDC, Earth Fact Sheet**: the Earth's mean radius. https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
- **NASA fact sheet "Super Lightweight External Tank"** and NASA's Space Shuttle External Tank figures: the dry-mass ratios of the aluminium and aluminium-lithium tanks. https://www.nasa.gov/sites/default/files/113020main_shuttle_lightweight.pdf
- **NASA Composite Cryotank Technologies and Demonstration project**: the weight saving of the composite tanks. https://ntrs.nasa.gov/citations/20150021410
- **NASA Apollo documents on the Lunar Module rendezvous radar** (NASA Technical Reports Server): the range and mass of the long-range rendezvous radar. https://ntrs.nasa.gov/api/citations/19690008704/downloads/19690008704.pdf
- **NASA Glenn Research Center, "Ideal Rocket Equation" and "Practical Rocketry"**: the propellant mass ratio and the lift-off thrust-to-weight check. https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/ideal-rocket-equation/ and https://www.grc.nasa.gov/www/k-12/rocket/TRCRocket/practical_rocketry.html

Inside the game, "Data sources" on the main menu lists the sources, and each part shows its own.

## Space Agency Partner Data and Other References

**Space Agency Partners**
- ISRO, "Stage Separation Systems for Launch Vehicles": why separating spent stages saves mass, in the staging model. https://www.isro.gov.in/media_isro/pdf/ResourcesPdf/SpaceIndia/publication%2837%29.pdf
- ESA, Space Debris Conference paper "Space Debris Management of Launch Operations": background for engine restarts and spent stages. https://conference.sdo.esoc.esa.int/proceedings/sdc7/paper/419/SDC7-paper419.pdf

**Other data**
- NGA, WGS 84 defining parameters: the Earth's gravitational parameter. https://earth-info.nga.mil/?action=wgs84&dir=wgs84
- BIPM, The International System of Units (SI brochure): standard gravity, 9.80665 m/s². https://www.bipm.org/en/publications/si-brochure
- Wikipedia articles quoting manufacturer figures, used for the engine classes (CC BY-SA 4.0): "Star (rocket stage)" and "Star 48" (Northrop Grumman), "Orion (rocket stage)", "SpaceX Merlin", "Rutherford (rocket engine)" (Rocket Lab), "RL10" (Aerojet Rocketdyne), and "Space Shuttle external tank" (NASA figures).
- H. D. Curtis, *Orbital Mechanics for Engineering Students*: the standard two-body equations (Kepler's equation, Lagrange coefficients, universal variable, Barker's equation). Only the standard equations were used; no text was copied.

**Tools and code**
- Godot Engine 4.7.2, MIT licence. https://godotengine.org
- AI coding agents: Claude Code (Anthropic) and OpenAI Codex; see "Use of SI".

**Art**
- All images are the team's own drawings. No third-party images, fonts or sounds were used.

Every source, with its URL, licence and where it is used in the code, is listed in `docs/references/` in the repository.
