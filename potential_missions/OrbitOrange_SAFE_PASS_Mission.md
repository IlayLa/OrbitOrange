# SAFE PASS — The Orbital Detour

**OrbitOrange mission concept**  
**Mission type:** Earth-orbiting satellite / collision-avoidance exercise  
**Difficulty:** Intermediate  
**Primary mechanics:** 2D Keplerian orbit propagation, impulsive burns, conjunction warning, ΔV budget, mission scoring

> **Design goal:** Give the player a reason to transition between orbital states as part of a mission objective—not merely to reach a target orbit. The player temporarily leaves a nominal circular orbit to avoid a predicted conjunction, then restores the original orbit and resumes the science campaign.

## 1. Mission briefing

You operate an Earth-observation satellite in a circular low-Earth orbit at an altitude of **800 km**. The satellite is collecting observations as it passes over Earth.

Mission control receives a conjunction warning: a tracked debris object is predicted to pass dangerously close to the spacecraft. The current trajectory is no longer acceptable.

You have a limited propellant budget and a short window in which to act. Your task is to execute a temporary orbital detour, allow the debris object to pass, and return to the original circular orbit without spending more ΔV than necessary.

The satellite must then resume its observation campaign.

## 2. Player objectives

1. Establish and maintain the nominal 800 km circular orbit.
2. Respond to the conjunction warning before the maneuver deadline.
3. Execute an avoidance burn that produces a temporary elliptical orbit.
4. Verify that the predicted closest approach is safely above the mission's minimum-separation threshold.
5. Execute a recovery burn at the planned point in the orbit to return to the original circular orbit.
6. Resume science observations and finish with a required propellant reserve.

The mission is successful only if the player avoids the conjunction **and** recovers the science orbit. Avoiding the debris but failing to restore the mission orbit is a partial success, not a full completion.

## 3. Mission flow

### Phase 1 — Establish the observation orbit

- Launch and insert the satellite into an 800 km circular orbit.
- Confirm that the orbit is within the science altitude band.
- Start the observation timer and begin collecting science points.

**Player feedback:** Display altitude, orbital speed, orbital period, remaining ΔV, and science progress.

### Phase 2 — Conjunction warning

A warning appears while the spacecraft is in its nominal orbit.

The warning should communicate:

- predicted time to closest approach;
- predicted miss distance if the spacecraft does nothing;
- the minimum acceptable miss distance for this scenario;
- time remaining before the avoidance maneuver must be performed.

The debris encounter should be represented by a simple scripted 2D trajectory or a lightweight conjunction event. The game does not need a full debris environment or probabilistic conjunction analysis.

**Player decision:** Perform the planned avoidance maneuver now, or wait and risk missing the maneuver window. For the first version, the mission can provide one recommended maneuver window and score the player on executing it correctly.

### Phase 3 — Temporary orbital detour

The player executes a radial impulse in the outward direction. This changes the spacecraft's circular orbit into an ellipse without requiring a new orbital-mechanics model.

For the reference maneuver below, the spacecraft begins at an 800 km circular orbit and receives an outward radial impulse of 200 m/s. The tangential velocity is unchanged.

The resulting orbit is approximately:

- **Perigee altitude:** 613 km
- **Apogee altitude:** 998 km
- **Semi-major axis:** approximately 7,183 km from Earth's centre
- **Orbital period:** approximately 101 minutes

The maneuver is intentionally simple: it modifies the radial velocity component, which the existing impulsive-burn system can represent.

The game should show the new elliptical trajectory, its perigee and apogee, and the debris object's predicted path. At the encounter time, calculate or script the closest separation and show whether the maneuver created a safe pass.

### Phase 4 — Recovery burn

After passing the encounter region, the spacecraft reaches the point on the opposite side of Earth where its inward radial velocity has the same magnitude as the initial outward impulse.

For the idealized reference case, this occurs about **52 minutes after the first burn**. The player performs a second outward radial impulse of approximately 200 m/s. This cancels the inward radial velocity while leaving the tangential velocity at the circular-orbit value.

The spacecraft therefore returns to the original 800 km circular orbit.

The game should not require the player to derive the timing from scratch. It can display a recovery marker or a countdown to the planned recovery point, while still requiring the player to execute the burn within a tolerance window.

### Phase 5 — Resume science operations

- Confirm that the orbit is circular again and within the 800 km target tolerance.
- Resume the observation timer.
- Complete the remaining science objective.
- Preserve the required propellant reserve.

## 4. Reference maneuver: why it works

Use the following constants for the reference case:

| Quantity | Value |
|---|---:|
| Earth gravitational parameter, μ | 398600.44 km³/s² |
| Earth mean radius used by the game | 6378.14 km |
| Initial altitude | 800 km |
| Initial orbital radius, r | 7178.14 km |
| Initial circular speed | approximately 7.451 km/s |
| First radial impulse | +0.200 km/s |
| Recovery radial impulse | +0.200 km/s |

At the first burn, the radial velocity changes from zero to +0.200 km/s while tangential velocity remains equal to the original circular speed. The resulting eccentricity is approximately 0.0268. The orbit has a perigee near 613 km and an apogee near 998 km.

At the corresponding point on the opposite side of the orbit, the radial velocity is approximately −0.200 km/s. Applying a +0.200 km/s radial impulse brings radial velocity back to zero. Since the tangential component is still the circular speed at the original radius, the spacecraft returns to the original circular orbit.

**Important:** These values describe an ideal two-body, impulsive-burn example. They are suitable as game reference values, not as real collision-avoidance guidance. A real maneuver would be planned using the actual spacecraft state, debris orbit, uncertainty, constraints, and mission flight rules.

## 5. Gameplay constraints and balancing

The mission should create meaningful decisions without introducing new subsystems.

### Suggested constraints

- **ΔV budget:** The player has enough propellant for the two reference burns, but not unlimited correction burns.
- **Maneuver window:** The first burn must be performed before a countdown expires.
- **Burn accuracy:** A burn that is too small may not create enough separation; a burn that is too large may make recovery harder or exceed the ΔV budget.
- **Recovery timing:** The second burn must be performed near the marked opposite-side point. Early or late execution leaves residual radial velocity and prevents a clean circular recovery.
- **Science interruption:** Science progress pauses during the avoidance and recovery phases. The player loses time but can still complete the campaign.

### Optional difficulty modifiers

These are optional and should not be required for the first playable version:

- Reduce the available ΔV reserve.
- Shorten the maneuver warning window.
- Add a small tolerance to the debris trajectory estimate.
- Require the player to choose between two candidate avoidance burns with different ΔV costs and miss distances.
- Add a secondary science deadline after the orbit is recovered.

## 6. Scoring

A simple scoring model can reward both safety and mission completion.

| Criterion | Suggested scoring behaviour |
|---|---|
| Collision avoidance | Full credit if closest approach exceeds the safe threshold; failure if it does not |
| Maneuver timing | Reward executing the avoidance burn within the recommended window |
| ΔV efficiency | More credit for using less than the maximum allowed ΔV |
| Orbit recovery | Full credit for returning to the target circular orbit within tolerance |
| Science completion | Credit for completing the remaining observation objective |
| Propellant reserve | Bonus for finishing with the required reserve |

**Suggested outcome states:**

- **Mission success:** Safe pass, successful orbit recovery, science objective complete, reserve preserved.
- **Partial success:** Safe pass achieved, but orbit recovery or science objective is incomplete.
- **Mission failure:** Collision threshold violated, propellant budget exceeded, or spacecraft leaves the allowed operating region.

## 7. Minimal implementation plan

This scenario is intended to reuse existing OrbitOrange systems wherever possible.

| Required feature | Implementation approach |
|---|---|
| Nominal 800 km orbit | Reuse the existing Earth-orbit mission setup |
| Impulsive radial burn | Reuse the existing burn interface; expose radial direction as a selectable burn direction if not already available |
| Elliptical orbit | Reuse the existing Keplerian propagation and orbit visualization |
| Conjunction warning | Reuse the existing conjunction event or a scripted mission event |
| Closest-approach result | Use the existing event result if supported; otherwise compare the two 2D positions at the scripted encounter time |
| Recovery point | Add a mission marker/countdown at the planned recovery location |
| Science objective | Reuse an existing altitude-band or observation objective |
| Score and ΔV reserve | Reuse the existing mission scoring and propellant accounting |

### What does not need to be built

The first version does **not** require:

- 3D orbital mechanics;
- attitude dynamics or reaction-wheel simulation;
- detailed debris catalogues;
- probabilistic conjunction assessment;
- battery, thermal, or ground-station models;
- continuous-thrust propulsion.

The event can be scripted in 2D around a single debris encounter. This keeps the mission focused on orbital transitions and makes it feasible within the current game architecture.

## 8. Acceptance criteria

The mission is ready for inclusion when:

1. The player can reach the initial 800 km circular orbit.
2. A conjunction warning appears at the specified mission time.
3. The outward radial burn creates the expected elliptical orbit within numerical tolerance.
4. The game displays the debris encounter and reports a safe or unsafe closest approach.
5. The recovery marker appears at the expected point in the orbit.
6. The second radial burn returns the spacecraft to an 800 km circular orbit within the configured tolerance.
7. Science observations resume after recovery.
8. The final score reflects collision avoidance, recovery, science completion, and ΔV usage.

## 9. Historical inspiration and scope

This is a fictionalized, simplified gameplay scenario inspired by NASA's operational lessons on orbital-debris collision avoidance.

NASA LLIS Lesson **1016**, *Collision Avoidance Maneuvers of the ISS Require Close, Real-Time Cooperation Between NASA and US Space Command*, describes the complexity of coordinating collision-avoidance decisions and maneuvers. It does not prescribe the specific two-radial-burn maneuver or the numerical orbit used in this game scenario.

Source: [NASA Lessons Learned Information System — Lesson 1016](https://llis.nasa.gov/lesson/1016)

The orbital values in this document are independently defined game parameters for an idealized two-body demonstration. They should not be presented as historical ISS maneuver data or as an operational real-spacecraft procedure.

---

## One-line mission pitch

**A debris warning forces your Earth-observation satellite out of its 800 km science orbit; execute a timed orbital detour, safely pass the debris, and restore the original orbit before your fuel and science window run out.**
