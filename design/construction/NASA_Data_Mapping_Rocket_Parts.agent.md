---
name: nasa-rocket-parts-data-map
description: Maps 29 rocket-design-game parts (categories ENG, MAT, TEL, SCI; tiers 1-3) to real NASA datasets (PDS, data.nasa.gov, Earthdata, NAIF SPICE) and to NASA Technical Reports Server (NTRS) engineering records. Use when asked which NASA dataset, archive or technical report corresponds to a game part, when a link or identifier for a part is needed, or when a NASA data-mapping report for this part list must be written.
version: 1.0.0
schema_version: 1
generated: 2026-11-15
source_input: parts_by_category_and_tier.html
record_count: 29
url_verification: "Every URL was returned by web search on 2026-11-15. Pages were not individually opened. Re-check with a fetch tool before presenting a link as live."
sidecar_json: NASA_Data_Mapping_Rocket_Parts.agent.json
---

# NASA Real-World Data Map for 29 Rocket Parts

Single source of truth is section 5 (records). Sections 3 and 4 are lookup aids derived from it.

## 1. Agent rules

Follow these in order.

1. **Look up by id.** Record ids have the form `<CAT>-<TIER>-<NN>`, for example `TEL-1-01`. `NN` is the position within the game's list for that category and tier.
2. **Route by `kind`.**
   - `dataset`: a public data product exists. Report `urls.primary` plus identifiers.
   - `hardware`: inert hardware. No dataset exists on data.nasa.gov or in the PDS. Say so explicitly, then report `ntrs_records` and `ntrs_search_terms`.
   - `method`: an engineering method with no data archive. Treat like `hardware`.
3. **Never invent URLs.** Use only URLs that appear in this file. If a record has no URL for something the user wants, say it is not in this map and run a search.
4. **Always state `fit` when it is not `direct`.** Use the definitions in section 2.
5. **Use `caveats`.** Repeat any non-empty `caveats` field when presenting that record.
6. **Versions drift.** Versioned datasets (ATL03 V6, EPIC L1B V4, MAVEN MAG 2.38, OLA 5.0) may have been superseded. If you have a fetch or search tool, confirm the current version before stating it as current.
7. **Dated snapshots.** URLs under `pds.nasa.gov/data/pds4/releases/` contain a date in the path. Prefer the node page (`urls.primary`) for the live archive.
8. **NTRS links.** `.../api/citations/<ID>/downloads/<ID>.pdf` opens the PDF. `.../citations/<ID>` opens the record page. If a record has `url: null`, only the NTRS id is known; search the id or title in NTRS.
9. **Copyright and quoting.** Paraphrase `description` and `data_details`. Do not reproduce long passages from the linked sources.
10. **Report format.** When asked for a report, use the template in section 6. Account for all 29 parts.

## 2. Schema

Each record is one YAML mapping.

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Stable key, `<CAT>-<TIER>-<NN>` |
| `game_part` | string | Part name exactly as in the input list |
| `category` | enum | `ENG` Engines, `MAT` Tanks, `TEL` Telemetry, `SCI` Science |
| `tier` | int | 1, 2 or 3 |
| `kind` | enum | `dataset`, `hardware`, `method` |
| `fit` | enum | See below |
| `analog` | string | The real-world dataset, mission, engine or tank that stands in for the part |
| `aliases` | list | Synonyms for retrieval |
| `mission` | string | Mission and instrument (dataset records) |
| `identifiers` | mapping | Dataset ids, DOIs, PDS logical identifiers where known |
| `description` | string | One or two sentences on what it is |
| `data_details` | string | Coverage, format, versions (dataset records) |
| `urls.primary` | string | Best single link |
| `urls.secondary` | list | `{label, url}` objects |
| `ntrs_records` | list | `{id, summary, url}` (hardware and method records) |
| `ntrs_search_terms` | list | Search strings for NTRS |
| `documentation_type` | string | What the NTRS records contain |
| `caveats` | string | Limits on how to use the mapping; empty if none |

**`fit` values**

| Value | Meaning |
|---|---|
| `direct` | The real item measures the same quantity or is the same hardware the part represents |
| `close_analog` | Same physical principle or role, different instrument or technique |
| `loose_analog` | Engineering subsystem with no real archive; the record is the nearest archived trace |
| `class_level` | No vehicle-specific public documentation; records cover the engine or tank class |

## 3. Index

| id | game_part | kind | fit | analog |
|---|---|---|---|---|
| ENG-1-01 | Cold-gas thruster | hardware | close_analog | Gravity Probe B cold-gas thrusters |
| ENG-1-02 | Small solid kick motor (Star 37 class) | hardware | direct | Thiokol Star 37 |
| ENG-2-01 | Solid motor (Star 48 class) | hardware | direct | Star 48 / PAM-D |
| ENG-2-02 | Small upper-stage engine (Rutherford class) | hardware | class_level | Electric pump-fed engine class |
| ENG-2-03 | Booster engine (Merlin class) | hardware | class_level | NASA Fastrac / MC-1 |
| ENG-3-01 | Large solid booster (Orion 50S XL class) | hardware | class_level | Five-segment Shuttle-derived booster |
| ENG-3-02 | Hydrogen upper-stage engine (RL10 class) | hardware | direct | RL10A-3-3A |
| MAT-1-01 | Small aluminium tank | hardware | close_analog | 2219 aluminium tankage |
| MAT-1-02 | Large aluminium tank | hardware | direct | Shuttle External Tank |
| MAT-2-01 | Small aluminium-lithium tank | hardware | class_level | Al-Li 2195 tank structure |
| MAT-2-02 | Large aluminium-lithium tank | hardware | direct | Shuttle Super Lightweight Tank |
| MAT-3-01 | Small carbon-composite tank | hardware | close_analog | Composite overwrapped pressure vessels |
| MAT-3-02 | Large carbon-composite tank | hardware | direct | NASA CCTD 5.5 m composite cryotank |
| TEL-1-01 | Temperature sensor | dataset | direct | MSL REMS |
| TEL-1-02 | Sun sensor | dataset | loose_analog | SORCE TIM total solar irradiance |
| TEL-1-03 | Basic altimeter | dataset | direct | MGS MOLA PEDR |
| TEL-1-04 | Basic onboard computer | dataset | loose_analog | Mars Pathfinder rover engineering data |
| TEL-1-05 | Basic proximity radar | dataset | close_analog | NEAR Laser Rangefinder |
| TEL-2-01 | Fuel gauge | method | loose_analog | Propellant gauging methods |
| TEL-2-02 | Tracking proximity radar | dataset | close_analog | OSIRIS-REx OLA |
| TEL-3-01 | Precise altimeter | dataset | direct | ICESat-2 ATL03 |
| TEL-3-02 | Star tracker | dataset | close_analog | NAIF SPICE C-kernels |
| TEL-3-03 | Radiation-hardened computer | dataset | loose_analog | MSL RAD |
| TEL-3-04 | Long-range rendezvous radar | dataset | close_analog | Arecibo / Goldstone asteroid radar |
| SCI-1-01 | Magnetometer | dataset | direct | MAVEN MAG |
| SCI-1-02 | Basic Earth camera | dataset | direct | DSCOVR EPIC L1B |
| SCI-2-01 | Atmosphere probe | dataset | direct | Galileo Probe ASI |
| SCI-3-01 | High-resolution Earth camera | dataset | direct | Astronaut photography of Earth |
| SCI-3-02 | Imaging radar | dataset | direct | Magellan F-MIDR |

## 4. Counts (use to verify completeness)

| Category | Parts | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|---|
| ENG | 7 | 2 | 3 | 2 |
| MAT | 6 | 2 | 2 | 2 |
| TEL | 11 | 5 | 2 | 4 |
| SCI | 5 | 2 | 1 | 2 |
| Total | 29 | 11 | 8 | 10 |

By `fit`: direct 14, close_analog 7, loose_analog 4, class_level 4.

## 5. Records

### 5.1 Engines (ENG)

```yaml
- id: ENG-1-01
  game_part: "Cold-gas thruster"
  category: ENG
  tier: 1
  kind: hardware
  fit: close_analog
  analog: "Gravity Probe B proportional cold-gas thrusters, plus other cold-gas attitude-control jets"
  aliases: ["cold gas jet", "RCS thruster", "attitude control thruster", "microthruster"]
  description: "Gravity Probe B used helium boil-off gas as propellant for 16 proportional thrusters. Other NTRS reports cover cold-gas jets running on nitrogen, freon, argon or helium."
  ntrs_records:
    - {id: "19830014044", summary: "GP-B attitude control and drag-compensation propulsion system (NASA TM-82517)", url: "https://ntrs.nasa.gov/api/citations/19830014044/downloads/19830014044.pdf"}
    - {id: "19960029259", summary: "GP-B microthruster analysis, computational and experimental", url: "https://ntrs.nasa.gov/citations/19960029259"}
    - {id: "19700019516", summary: "SPARCS solar-pointing control system; cold-gas jets on selectable gases", url: "https://ntrs.nasa.gov/api/citations/19700019516/downloads/19700019516.pdf"}
    - {id: "19750015604", summary: "Attitude control propulsion components with cold-gas jet valve data sheets", url: "https://ntrs.nasa.gov/api/citations/19750015604/downloads/19750015604.pdf"}
  ntrs_search_terms: ["cold gas thruster", "attitude control thruster", "proportional microthruster"]
  documentation_type: "System design, valve data sheets, thruster test analysis"
  caveats: "An earlier draft wrongly said GP-B used nitrogen. It used helium boil-off gas."

- id: ENG-1-02
  game_part: "Small solid kick motor (Star 37 class)"
  category: ENG
  tier: 1
  kind: hardware
  fit: direct
  analog: "Thiokol Star 37 (TE-M-364), which originated as the Surveyor lunar lander retro motor"
  aliases: ["Star 37", "TE-M-364", "apogee kick motor", "AKM"]
  description: "NTRS holds an apogee-kick-motor nozzle failure analysis that describes the Star 37 family, plus reliability and design reports for apogee motors."
  ntrs_records:
    - {id: "19820002238", summary: "Ayame/PAM-D apogee kick motor nozzle failure analysis; describes Star 37 and Star 48", url: "https://ntrs.nasa.gov/api/citations/19820002238/downloads/19820002238.pdf"}
    - {id: "19740009398", summary: "Solid-rocket motor reliability study covering upper-stage and apogee motors", url: "https://ntrs.nasa.gov/api/citations/19740009398/downloads/19740009398.pdf"}
    - {id: "19700011467", summary: "Applications Technology Satellite apogee rocket motor summary report (JPL TM 33-338)", url: "https://ntrs.nasa.gov/api/citations/19700011467/downloads/19700011467.pdf"}
  ntrs_search_terms: ["Star 37", "TE-M-364", "apogee kick motor"]
  documentation_type: "Motor description, performance weights, failure analysis"
  caveats: ""

- id: ENG-2-01
  game_part: "Solid motor (Star 48 class)"
  category: ENG
  tier: 2
  kind: hardware
  fit: direct
  analog: "Star 48 / Star 48B (TE-M-711-3), the PAM-D motor; also a third stage on New Horizons"
  aliases: ["Star 48", "Star 48B", "PAM-D", "TE-M-711"]
  description: "NTRS documents the Star 48 as the PAM-D propulsion unit and includes flight-history and Shuttle upper-stage integration papers."
  ntrs_records:
    - {id: "19820002238", summary: "PAM-D Star 48 motor description, shuttle and Delta versions", url: "https://ntrs.nasa.gov/api/citations/19820002238/downloads/19820002238.pdf"}
    - {id: "20180006390", summary: "Solid rocket motor incremental modeling; lists Star 48B flights including Delta II, Ulysses and New Horizons", url: "https://ntrs.nasa.gov/api/citations/20180006390/downloads/20180006390.pdf"}
    - {id: "20030007859", summary: "IRIS-GUS Shuttle upper stage built around the Star-48B", url: "https://ntrs.nasa.gov/api/citations/20030007859/downloads/20030007859.pdf"}
  ntrs_search_terms: ["Star 48", "PAM-D", "Star-48B"]
  documentation_type: "Motor description, ballistic performance, mission-use studies"
  caveats: ""

- id: ENG-2-02
  game_part: "Small upper-stage engine (Rutherford class)"
  category: ENG
  tier: 2
  kind: hardware
  fit: class_level
  analog: "Rutherford (Rocket Lab Electron), an electric-pump-fed engine; class-level coverage only"
  aliases: ["Rutherford", "electric pump-fed engine", "electropump", "Electron engine"]
  description: "NTRS has a study comparing battery-powered motor-driven pumps with turbopumps for a 1000 lbf bipropellant engine."
  ntrs_records:
    - {id: "19800023905", summary: "Propellant feed system study: battery-powered motor-driven pumps versus turbopumps", url: "https://ntrs.nasa.gov/api/citations/19800023905/downloads/19800023905.pdf"}
  ntrs_search_terms: ["motor-driven pump", "electric pump feed system", "battery powered pump rocket engine"]
  documentation_type: "Pump-drive trade studies"
  caveats: "No Rutherford-specific data is expected in NTRS. Proprietary vehicle."

- id: ENG-2-03
  game_part: "Booster engine (Merlin class)"
  category: ENG
  tier: 2
  kind: hardware
  fit: class_level
  analog: "NASA Fastrac / MC-1, a 60,000 lbf LOX/RP-1 gas-generator engine. Merlin itself is not in NTRS."
  aliases: ["Merlin", "Merlin 1D", "Fastrac", "MC-1", "LOX/RP-1 gas generator", "kerolox booster"]
  description: "NTRS reports on the MC-1 (Fastrac) engine, including 48 development tests on three engines across three test stands."
  ntrs_records:
    - {id: "20000097369", summary: "Development status of the NASA MC-1 (Fastrac) engine, Ballard and Olive, 2000", url: "https://ntrs.nasa.gov/citations/20000097369"}
    - {id: "19770016250", summary: "LOX/RP-1 gas-generator-cycle engine studies for single-stage-to-orbit", url: "https://ntrs.nasa.gov/api/citations/19770016250/downloads/19770016250.pdf"}
    - {id: "20000064017", summary: "Fastrac gas generator component test program and results (id only, identified from a secondary reference)", url: null}
  ntrs_search_terms: ["Fastrac", "MC-1 engine", "LOX/RP-1 gas generator"]
  documentation_type: "Engine cycle and test-program reports"
  caveats: "Claim that Fastrac design principles carried into Merlin 1A comes from Wikipedia mirrors, not NTRS. Unverified against a primary source. Vehicle-specific data is mostly proprietary."

- id: ENG-3-01
  game_part: "Large solid booster (Orion 50S XL class)"
  category: ENG
  tier: 3
  kind: hardware
  fit: class_level
  analog: "No Orion 50S XL record found in NTRS. Nearest NASA-documented analog is the Shuttle-derived five-segment booster (Ares I first stage, SLS)."
  aliases: ["Orion 50S XL", "Pegasus first stage", "five-segment booster", "RSRMV", "SLS booster", "Shuttle SRB"]
  description: "NTRS documents the five-segment motor, including development-motor static tests and the rationale for choosing it as the Ares I first stage."
  ntrs_records:
    - {id: "20120014501", summary: "Five-segment solid rocket motor development status, DM-1 to DM-3 static tests", url: "https://ntrs.nasa.gov/api/citations/20120014501/downloads/20120014501.pdf"}
    - {id: "20080000774", summary: "Ares I first-stage propulsion choice and development", url: "https://ntrs.nasa.gov/api/citations/20080000774/downloads/20080000774.pdf"}
    - {id: "20100020957", summary: "Ares first-stage milestone summary including DM-1 firing", url: "https://ntrs.nasa.gov/api/citations/20100020957/downloads/20100020957.pdf"}
  ntrs_search_terms: ["five-segment booster", "solid rocket motor static test", "Ares I first stage"]
  documentation_type: "Static-test results, motor design changes, performance"
  caveats: "Orion 50S XL is a commercial Pegasus motor with no NTRS record found. The mapped booster is a different, larger motor."

- id: ENG-3-02
  game_part: "Hydrogen upper-stage engine (RL10 class)"
  category: ENG
  tier: 3
  kind: hardware
  fit: direct
  analog: "RL10A-3-3A (Centaur), a full expander-cycle LH2/LOX engine"
  aliases: ["RL10", "Centaur engine", "expander cycle", "hydrolox upper stage"]
  description: "NTRS holds engine system modeling, full-scale Centaur propulsion tests and component design reports for the RL10."
  ntrs_records:
    - {id: "19950022693", summary: "Transient model of the RL10A-3-3A rocket engine", url: "https://ntrs.nasa.gov/api/citations/19950022693/downloads/19950022693.pdf"}
    - {id: "19950017370", summary: "RL10 simulation activity", url: "https://ntrs.nasa.gov/api/citations/19950017370/downloads/19950017370.pdf"}
    - {id: "19740011284", summary: "Propulsion system tests on a full-scale Centaur (NASA TM X-71511)", url: "https://ntrs.nasa.gov/api/citations/19740011284/downloads/19740011284.pdf"}
    - {id: "19890014148", summary: "RL10 derivative II chamber and primary nozzle design, fabrication and test", url: "https://ntrs.nasa.gov/citations/19890014148"}
  ntrs_search_terms: ["RL10", "Centaur upper stage engine", "expander cycle"]
  documentation_type: "Engine modeling, restart and thermal conditioning tests, component design"
  caveats: ""
```

### 5.2 Tanks (MAT)

```yaml
- id: MAT-1-01
  game_part: "Small aluminium tank"
  category: MAT
  tier: 1
  kind: hardware
  fit: close_analog
  analog: "2219 aluminium alloy propellant tankage"
  aliases: ["aluminum tank", "2219 aluminum", "welded aluminum tank"]
  description: "NTRS covers welding of the Shuttle External Tank 2219 pressure vessel and design studies for 2219 Shuttle tankage."
  ntrs_records:
    - {id: "19800062506", summary: "Welding of the Space Shuttle External Tank (2219 pressure-vessel fabrication)", url: "https://ntrs.nasa.gov/citations/19800062506"}
    - {id: "19750013268", summary: "Weight and cost design studies for 2219 aluminium Shuttle tankage concepts", url: "https://ntrs.nasa.gov/api/citations/19750013268/downloads/19750013268.pdf"}
  ntrs_search_terms: ["aluminum 2219 propellant tank", "welded aluminum tank design"]
  documentation_type: "Welding, materials and structural design"
  caveats: "No small-tank-specific record found; Shuttle-scale documents are used as the analog."

- id: MAT-1-02
  game_part: "Large aluminium tank"
  category: MAT
  tier: 1
  kind: hardware
  fit: direct
  analog: "Space Shuttle External Tank (standard and lightweight 2219 versions)"
  aliases: ["External Tank", "ET", "Shuttle tank"]
  description: "NTRS holds an External Tank program retrospective on key design features and evolution, plus a Shuttle propulsion design overview."
  ntrs_records:
    - {id: "20120001570", summary: "External Tank Program: Legacy of Success", url: "https://ntrs.nasa.gov/citations/20120001570"}
    - {id: "20110014620", summary: "Designing the Space Shuttle propulsion system, session overview", url: "https://ntrs.nasa.gov/api/citations/20110014620/downloads/20110014620.pdf"}
  ntrs_search_terms: ["Space Shuttle External Tank", "lightweight tank 2219"]
  documentation_type: "Design features, manufacturing, design evolution"
  caveats: ""

- id: MAT-2-01
  game_part: "Small aluminium-lithium tank"
  category: MAT
  tier: 2
  kind: hardware
  fit: class_level
  analog: "Al-Li 2195 tank structure"
  aliases: ["aluminum lithium tank", "Al-Li 2195", "2195"]
  description: "NTRS covers the Super Lightweight Tank design, which substitutes 2195 Al-Li for 2219, and friction stir welding of 2195."
  ntrs_records:
    - {id: "19950023907", summary: "Super Lightweight External Tank design, substituting 2195 Al-Li", url: "https://ntrs.nasa.gov/api/citations/19950023907/downloads/19950023907.pdf"}
    - {id: "20020015869", summary: "Friction stir welding development at NASA MSFC covering 2195, 2219 and 7075", url: "https://ntrs.nasa.gov/api/citations/20020015869/downloads/20020015869.pdf"}
  ntrs_search_terms: ["aluminum lithium 2195", "Al-Li tank weldability"]
  documentation_type: "Alloy characterization and joining"
  caveats: "No small-tank-specific record found. An earlier draft cited Orion structure; that claim was removed as unsupported."

- id: MAT-2-02
  game_part: "Large aluminium-lithium tank"
  category: MAT
  tier: 2
  kind: hardware
  fit: direct
  analog: "Space Shuttle Super Lightweight Tank (SLWT)"
  aliases: ["SLWT", "super lightweight tank", "2195 external tank"]
  description: "NTRS holds the SLWT structural verification, aimed at removing 7,500 lb from a 65,400 lb External Tank."
  ntrs_records:
    - {id: "20010000456", summary: "Structural verification of the Shuttle External Tank Super LightWeight design (Otte)", url: "https://ntrs.nasa.gov/citations/20010000456"}
    - {id: "19950023907", summary: "Super Lightweight External Tank design, substituting 2195 Al-Li", url: "https://ntrs.nasa.gov/api/citations/19950023907/downloads/19950023907.pdf"}
  ntrs_search_terms: ["Super Lightweight Tank", "SLWT 2195"]
  documentation_type: "Structural verification, weight-reduction analysis"
  caveats: ""

- id: MAT-3-01
  game_part: "Small carbon-composite tank"
  category: MAT
  tier: 3
  kind: hardware
  fit: close_analog
  analog: "Composite overwrapped pressure vessels (COPV)"
  aliases: ["COPV", "composite pressure vessel", "overwrapped tank"]
  description: "NTRS holds stress-rupture mechanics, reliability models and White Sands test reports for COPVs."
  ntrs_records:
    - {id: "20260002192", summary: "Mechanics of stress-rupture failure in carbon-fiber COPVs (NASA/TM-20260002192, March 2026)", url: "https://ntrs.nasa.gov/citations/20260002192"}
    - {id: "20120013821", summary: "COPV stress-rupture reliability accounting for design-burst margin", url: "https://ntrs.nasa.gov/citations/20120013821"}
    - {id: "20100021151", summary: "COPV stress-rupture testing at White Sands Test Facility", url: "https://ntrs.nasa.gov/citations/20100021151"}
  ntrs_search_terms: ["composite overwrapped pressure vessel", "COPV stress rupture"]
  documentation_type: "Burst and stress-rupture test data, reliability models"
  caveats: "COPVs are pressure vessels, not propellant tanks. Used as the closest small composite analog."

- id: MAT-3-02
  game_part: "Large carbon-composite tank"
  category: MAT
  tier: 3
  kind: hardware
  fit: direct
  analog: "NASA Composite Cryotank Technologies and Demonstration (CCTD): 2.4 m precursor and 5.5 m out-of-autoclave tanks built by Boeing, tested at MSFC with liquid hydrogen"
  aliases: ["CCTD", "composite cryotank", "out-of-autoclave tank", "5.5 m tank"]
  description: "NTRS holds the 2.4 m and 5.5 m test results and a design, manufacture and test chapter. NASA also keeps an archived project page."
  ntrs_records:
    - {id: "20150021410", summary: "CCTD 2.4 m and 5.5 m out-of-autoclave tank test results", url: "https://ntrs.nasa.gov/citations/20150021410"}
    - {id: "20170012407", summary: "Design, manufacture and test of cryotank components (book chapter)", url: "https://ntrs.nasa.gov/citations/20170012407"}
  urls:
    primary: "https://www.nasa.gov/directorates/stmd/composite-cryotank-technologies-and-demonstration-cctd/"
    secondary: []
  ntrs_search_terms: ["composite cryotank", "CCTD", "out-of-autoclave cryogenic tank"]
  documentation_type: "Manufacturing, cryogenic pressure testing, structural design"
  caveats: "NASA project page is archived and no longer updated."
```

### 5.3 Telemetry (TEL)

```yaml
- id: TEL-1-01
  game_part: "Temperature sensor"
  category: TEL
  tier: 1
  kind: dataset
  fit: direct
  analog: "MSL Rover Environmental Monitoring Station (REMS) Reduced Data Records"
  aliases: ["thermometer", "air temperature", "ground temperature", "Curiosity weather station"]
  mission: "Mars Science Laboratory (Curiosity), Gale Crater, Mars"
  identifiers:
    pds3_dataset_ids: ["MSL-M-REMS-2-EDR-V1.0", "MSL-M-REMS-3-TELRDR-V1.0"]
  description: "REMS is MSL's primary meteorological instrument. It records wind speed and direction, pressure, relative humidity, air temperature, ground temperature and UV radiation."
  data_details: "Certified data from sol 1 (2012-08-07) onward, ongoing. Processed variants: TELRDR (electrical and thermal units), ENVRDR (environmental magnitudes), MODRDR (corrected). Raw EDR also available."
  urls:
    primary: "https://atmos.nmsu.edu/data_and_services/atmospheres_data/MARS/curiosity/rems.html"
    secondary:
      - {label: "PDS4 release directory (dated snapshot)", url: "https://pds.nasa.gov/data/pds4/releases/atmos/msl_rems-20260803/"}
      - {label: "Catalog record, raw EDR", url: "https://catalog.data.gov/dataset/msl-mars-rover-environmental-monitoring-station-2-edr-v1-0-a7f6f"}
  caveats: "PDS4 release folder is a dated snapshot. Use the node page for the live archive."

- id: TEL-1-02
  game_part: "Sun sensor"
  category: TEL
  tier: 1
  kind: dataset
  fit: loose_analog
  analog: "SORCE Level 3 Total Solar Irradiance Daily Means V019 (SOR3TSID)"
  aliases: ["solar sensor", "solar irradiance", "solar constant", "TSI"]
  mission: "Solar Radiation and Climate Experiment (SORCE), Total Irradiance Monitor (TIM)"
  identifiers:
    short_names: ["SOR3TSID", "SOR3TSI6"]
    dois: ["10.5067/7C82ZHS0OPFR (daily)", "10.5067/T6IX3V0XGBAN (6-hour)"]
  description: "Total solar irradiance measured by an active-cavity radiometer in low Earth orbit, averaged daily. Version 019 is the final version and supersedes earlier ones."
  data_details: "Coverage 2003-02-25 to 2020-02-25. A 6-hour product (SOR3TSI6) also exists."
  urls:
    primary: "https://disc.gsfc.nasa.gov/datacollection/SOR3TSID_019.html"
    secondary:
      - {label: "LASP TSI data page", url: "https://lasp.colorado.edu/sorce/data/tsi-data/"}
      - {label: "Catalog record, 6-hour means", url: "https://catalog.data.gov/dataset/sorce-level-3-total-solar-irradiance-6-hour-means-v019-sor3tsi6-at-ges-disc"}
  caveats: "Spacecraft attitude-control sun sensors do not publish science archives. This is the nearest solar-pointing observational record."

- id: TEL-1-03
  game_part: "Basic altimeter"
  category: TEL
  tier: 1
  kind: dataset
  fit: direct
  analog: "MOLA Precision Experiment Data Record"
  aliases: ["laser altimeter", "MOLA", "Mars topography"]
  mission: "Mars Global Surveyor, Mars Orbiter Laser Altimeter"
  identifiers:
    pds3_dataset_ids: ["MGS-M-MOLA-3-PEDR-L1A-V1.0"]
  description: "Along-track science-mode laser altimeter telemetry converted to engineering and physical units. The instrument measures round-trip pulse time of flight to the surface."
  data_details: "Binary PEDR files with PDS labels, one orbit per product. ASCII table derivative exists. Footprints about 168 m across."
  urls:
    primary: "https://data.nasa.gov/dataset/mola-precision-experiment-data-record-15a65"
    secondary:
      - {label: "PDS dataset record", url: "https://pds.nasa.gov/ds-view/pds/viewDataset.jsp?dsid=MGS-M-MOLA-3-PEDR-L1A-V1.0"}
      - {label: "Archive volume readme", url: "https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-3-pedr-l1a-v1/mgsl_21xx/aareadme.htm"}
  caveats: ""

- id: TEL-1-04
  game_part: "Basic onboard computer"
  category: TEL
  tier: 1
  kind: dataset
  fit: loose_analog
  analog: "Mars Pathfinder Rover Engineering EDR/RDR"
  aliases: ["flight computer", "CDH telemetry", "housekeeping telemetry", "engineering telemetry"]
  mission: "Mars Pathfinder, Sojourner rover"
  identifiers:
    pds3_dataset_ids: ["MPFR-M-RVRENG-2/3-EDR/RDR-V1.0"]
  description: "Raw and engineering-unit values for every rover telemetry channel, one directory per sol plus cruise health checks. Nearest public archive of flight-computer housekeeping data."
  data_details: "75 subdirectories: one per sol of the surface mission plus two cruise health checks."
  urls:
    primary: "https://pds.nasa.gov/data/mpfr-m-apxs-2-edr-v1.0/mprv_0001/catalog/rvrengds.cat"
    secondary: []
  caveats: "No canonical onboard-computer dataset exists. This is an engineering-telemetry stand-in."

- id: TEL-1-05
  game_part: "Basic proximity radar"
  category: TEL
  tier: 1
  kind: dataset
  fit: close_analog
  analog: "NEAR Laser Rangefinder (NLR) PDS4 bundle"
  aliases: ["proximity ranging", "NLR", "Eros altimetry"]
  mission: "NEAR Shoemaker at asteroid 433 Eros"
  identifiers:
    pds4_lid: "urn:nasa:pds:near.nlr"
    pds3_dataset_ids: ["NEAR_A_NLR_2_EDR_EROS_ORBIT_V1_0", "NEAR_A_NLR_5_CDR_EROS_ORBIT_V1_0"]
  description: "A laser altimeter that measured spacecraft-to-surface distance using short laser bursts. The bundle holds raw and calibrated Eros-orbit data and documentation, migrated from PDS3 to PDS4 in 2022 to 2024."
  data_details: "Bundle overview dated 2024-06-10."
  urls:
    primary: "https://sbnarchive.psi.edu/pds4/near/near.nlr/document/nlr_bundle_overview.pdf"
    secondary:
      - {label: "Catalog record, Level 2 products", url: "https://catalog.data.gov/dataset/near-nlr-level-2-data-products-v1-0-b1255"}
  caveats: "Laser ranging, not radar."

- id: TEL-2-01
  game_part: "Fuel gauge"
  category: TEL
  tier: 2
  kind: method
  fit: loose_analog
  analog: "Spacecraft propellant gauging methods: bookkeeping, pressure-volume-temperature (PVT), thermal capacitance"
  aliases: ["propellant gauge", "fuel quantity", "propellant remaining", "PVT gauging", "mass gauging"]
  description: "No public dataset exists. Propellant gauging is an engineering telemetry method documented in NTRS. PVT uses real-gas relations for the pressurant; bookkeeping integrates burn history; thermal gauging uses tank temperature response."
  ntrs_records:
    - {id: "19920004878", summary: "Propellant-remaining estimation methods including PVT, for the GRO satellite", url: "https://ntrs.nasa.gov/api/citations/19920004878/downloads/19920004878.pdf"}
    - {id: "20130000279", summary: "MMS propellant gauging by thermal model; compares bookkeeping, PVT and thermal capacitance", url: "https://ntrs.nasa.gov/api/citations/20130000279/downloads/20130000279.pdf"}
    - {id: "20150023077", summary: "Low-gravity propellant quantity gauging, state of the art", url: "https://ntrs.nasa.gov/api/citations/20150023077/downloads/20150023077.pdf"}
    - {id: "19770003201", summary: "Shuttle OMS PVT propellant gauging module", url: "https://ntrs.nasa.gov/api/citations/19770003201/downloads/19770003201.pdf"}
  ntrs_search_terms: ["propellant gauging", "pressure-volume-temperature gauging", "bookkeeping method"]
  documentation_type: "Method descriptions and accuracy analyses"
  caveats: "Engineering method, not a data archive."

- id: TEL-2-02
  game_part: "Tracking proximity radar"
  category: TEL
  tier: 2
  kind: dataset
  fit: close_analog
  analog: "OSIRIS-REx Laser Altimeter (OLA) Bundle 5.0"
  aliases: ["OLA", "Bennu lidar", "proximity lidar"]
  mission: "OSIRIS-REx at asteroid Bennu"
  identifiers:
    pds4_lidvid: "urn:nasa:pds:orex.ola::5.0"
    dois: ["10.26033/g7ym-d692"]
  description: "All operational OLA data products, used for topographic characterization of Bennu. V21 strip-adjusted products are the final ones for science use; V20 is kept for history."
  data_details: "Bundle 5.0 published 2024-05-28, curated by the PDS Small Bodies Node."
  urls:
    primary: "https://sbn.psi.edu/pds/resource/doi/orex_ola_5.0.html"
    secondary:
      - {label: "DOI", url: "https://doi.org/10.26033/g7ym-d692"}
      - {label: "Derived altimetry shape models", url: "https://sbn.psi.edu/pds/resource/doi/orex_altimetry_1.0.html"}
  caveats: "Lidar, not radar. Newer bundle versions may exist."

- id: TEL-3-01
  game_part: "Precise altimeter"
  category: TEL
  tier: 3
  kind: dataset
  fit: direct
  analog: "ATLAS/ICESat-2 L2A Global Geolocated Photon Data, Version 6 (ATL03)"
  aliases: ["photon-counting altimeter", "ICESat-2", "ATLAS", "ATL03"]
  mission: "ICESat-2, ATLAS photon-counting laser altimeter"
  identifiers:
    dois: ["10.5067/ATLAS/ATL03.006"]
    short_names: ["ATL03"]
  description: "Height above the WGS 84 ellipsoid, latitude, longitude and time for every photon the ATLAS instrument downlinks. Base product for higher-level ICESat-2 products."
  data_details: "Version 6 added photon weights and dynamically computed sigma_h. Versions 1, 2, 3 and 5 are marked deprecated on Earthdata."
  urls:
    primary: "https://www.earthdata.nasa.gov/data/catalog/nsidc-cprd-atl03-006"
    secondary:
      - {label: "DOI", url: "https://doi.org/10.5067/ATLAS/ATL03.006"}
  caveats: "Confirm the current version before stating it as latest."

- id: TEL-3-02
  game_part: "Star tracker"
  category: TEL
  tier: 3
  kind: dataset
  fit: close_analog
  analog: "NAIF SPICE C-kernels (CK)"
  aliases: ["attitude sensor", "pointing", "quaternion", "orientation kernel", "CK"]
  mission: "Multi-mission; archived by the PDS NAIF node"
  identifiers:
    pds4_lid: "mission-specific SPICE bundles, for example InSight SPICE"
  description: "Star trackers output attitude. Missions archive it as time-tagged spacecraft orientation in SPICE C-kernels, not as science datasets."
  urls:
    primary: "https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/FORTRAN/req/ck.html"
    secondary:
      - {label: "Example archive description (InSight SPICE)", url: "https://naif.jpl.nasa.gov/pub/naif/pds/pds4/insight/insight_spice/document/spiceds_v001.html"}
      - {label: "NAIF SPICE concept overview", url: "https://naif.jpl.nasa.gov/naif/spiceconcept.html"}
  caveats: "Mission-specific kernels; pick a mission to get actual files."

- id: TEL-3-03
  game_part: "Radiation-hardened computer"
  category: TEL
  tier: 3
  kind: dataset
  fit: loose_analog
  analog: "MSL Radiation Assessment Detector (RAD) Reduced Data Records"
  aliases: ["rad-hard processor", "radiation environment", "RAD750", "space radiation"]
  mission: "Mars Science Laboratory (Curiosity) and cruise stage"
  identifiers:
    pds3_dataset_ids: ["MSL-M-RAD-3-RDR-V1.0", "MSL-M-RAD-2-EDR-V1.0"]
  description: "Radiation measurements from interplanetary cruise and the Martian surface. This is the environment rad-hard processors are designed to survive."
  urls:
    primary: "https://pds-ppi.igpp.ucla.edu/data/MSL-M-RAD-3-RDR-V1.0/AAREADME.TXT"
    secondary:
      - {label: "Raw EDR dataset record", url: "https://pds.nasa.gov/ds-view/pds/viewDataset.jsp?dsid=MSL-M-RAD-2-EDR-V1.0"}
      - {label: "RDR Software Interface Specification", url: "https://pds-ppi.igpp.ucla.edu/archive1/MSLRAD_1002/DOCUMENT/RAD_RDR_SIS.HTM"}
  caveats: "The computer itself produces no science data. Environment analog only."

- id: TEL-3-04
  game_part: "Long-range rendezvous radar"
  category: TEL
  tier: 3
  kind: dataset
  fit: close_analog
  analog: "Arecibo radar imaging and Doppler spectroscopy (PDS4, asteroids), plus JPL Small-Body Radar Astrometry"
  aliases: ["delay-Doppler", "planetary radar", "asteroid radar", "Goldstone radar", "ranging radar"]
  mission: "Ground-based: Arecibo Observatory and Goldstone planetary radar"
  identifiers:
    pds4_bundle_directory: "gbo.ast.radar.arecibo.doppler_spectra_of_asteroids"
  description: "The Arecibo bundle provides processed Doppler spectra (CSV) and delay-Doppler images (FITS) from the 12.6 cm and 70 cm radar systems. The JPL API returns delay and Doppler measurements for asteroids and comets."
  urls:
    primary: "https://ssd-api.jpl.nasa.gov/doc/sb_radar.html"
    secondary:
      - {label: "Arecibo bundle description", url: "https://sbnarchive.psi.edu/pds4/non_mission/gbo.ast.radar.arecibo.doppler_spectra_of_asteroids/document/individual.arecibo_radar_imaging_and_doppler_spectroscopy.txt"}
      - {label: "Arecibo Doppler data format", url: "https://sbnarchive.psi.edu/pds4/non_mission/gbo.ast.radar.arecibo.doppler_spectra_of_asteroids/document/DopplerDataFormat.pdf"}
  caveats: "Ground-based data. No spacecraft rendezvous-radar archive is public."
```

### 5.4 Science (SCI)

```yaml
- id: SCI-1-01
  game_part: "Magnetometer"
  category: SCI
  tier: 1
  kind: dataset
  fit: direct
  analog: "MAVEN MAG Calibrated Data Bundle"
  aliases: ["magnetic field", "MAG", "MAVEN magnetometer"]
  mission: "MAVEN, Mars"
  identifiers:
    pds4_lid: "urn:nasa:pds:maven.mag.calibrated"
    dois: ["10.17189/1414178"]
  description: "ASCII time series of magnetic-field vectors in nanotesla, corrected for instrument and spacecraft effects and transformed into physical coordinate systems, for all mission phases."
  data_details: "Bundle version 2.38 (June 2026). Coordinate-system collections: payload (pl), planetocentric (pc), Sun-State (ss). Related bundle: urn:nasa:pds:maven.insitu.calibrated."
  urls:
    primary: "https://data.nasa.gov/dataset/maven-mag-calibrated-data-bundle-6d6b3"
    secondary:
      - {label: "PPI readme", url: "https://pds-ppi.igpp.ucla.edu/data/maven-mag-calibrated/Readme_2.38.txt"}
      - {label: "DOI", url: "https://doi.org/10.17189/1414178"}
  caveats: "Incremental releases continue; confirm current version."

- id: SCI-1-02
  game_part: "Basic Earth camera"
  category: SCI
  tier: 1
  kind: dataset
  fit: direct
  analog: "DSCOVR EPIC Level 1B, Version 4"
  aliases: ["Earth imager", "EPIC", "full-disk Earth image", "Blue Marble camera"]
  mission: "DSCOVR, Earth Polychromatic Imaging Camera at the Earth-Sun L1 point"
  identifiers:
    dois: ["10.5067/EPIC/DSCOVR/L1B.003 (Version 3)"]
  description: "Calibrated, geolocated EPIC images of Earth with ancillary metadata. EPIC is a 10-channel spectro-radiometer covering 317 to 780 nm."
  data_details: "HDF5 format, hosted at the Atmospheric Science Data Center (ASDC). Version 4 was announced in July 2026. Version 3 remains available."
  urls:
    primary: "https://data.nasa.gov/dataset/dscovr-epic-level-1b-version-4"
    secondary:
      - {label: "ASDC project page", url: "https://asdc.larc.nasa.gov/project/DSCOVR"}
      - {label: "Data Format Control Book", url: "https://asdc.larc.nasa.gov/documents/dscovr/EPIC_Data_Format_Control_Book.pdf"}
  caveats: ""

- id: SCI-2-01
  game_part: "Atmosphere probe"
  category: SCI
  tier: 2
  kind: dataset
  fit: direct
  analog: "Galileo Probe Atmospheric Structure Instrument (ASI)"
  aliases: ["entry probe", "atmospheric structure", "Jupiter probe", "ASI"]
  mission: "Galileo Probe, Jupiter entry and descent, December 1995"
  identifiers:
    pds3_dataset_ids: ["GP-J-ASI-3-ENTRY-V1.0"]
  description: "Measured temperature, pressure and density of Jupiter's atmosphere from nanobar levels to about 24 bars, reaching roughly 160 km depth during the parachute descent."
  data_details: "Reduced upper-atmosphere and descent files include altitude, pressure, temperature, density, mean molecular weight and probe velocity."
  urls:
    primary: "https://atmos.nmsu.edu/data_and_services/atmospheres_data/Galileo/asi.html"
    secondary:
      - {label: "PDS dataset record", url: "https://pds.nasa.gov/ds-view/pds/viewDataset.jsp?dsid=GP-J-ASI-3-ENTRY-V1.0"}
      - {label: "ASI file description", url: "https://pds.nasa.gov/data/gp-j-had-3-entry-v1.0/gp_0001/DATA/ASI/ASIINFO.TXT"}
  caveats: ""

- id: SCI-3-01
  game_part: "High-resolution Earth camera"
  category: SCI
  tier: 3
  kind: dataset
  fit: direct
  analog: "Gateway to Astronaut Photography of Earth (ISS and earlier crew photography)"
  aliases: ["astronaut photography", "ISS Earth photos", "handheld camera", "Earth from space photos"]
  mission: "Crewed missions in low Earth orbit"
  identifiers: {}
  description: "Hand-held photographs of Earth from crewed spacecraft with searchable location metadata."
  data_details: "Resolution, revisit time, obliquity and cloud cover vary. Coverage is not uniform."
  urls:
    primary: "https://eol.jsc.nasa.gov/searchphotos/"
    secondary: []
  caveats: "Search interface rather than a single bundled dataset. An API is referenced on the page."

- id: SCI-3-02
  game_part: "Imaging radar"
  category: SCI
  tier: 3
  kind: dataset
  fit: direct
  analog: "Magellan Full-resolution Mosaic Image Data Records (F-MIDR)"
  aliases: ["SAR", "synthetic aperture radar", "Venus radar", "Magellan"]
  mission: "Magellan, synthetic aperture radar, Venus"
  identifiers:
    pds3_dataset_ids: ["MGN-V-RDRS-5-MIDR-FULL-RES-V1.0"]
  description: "SAR mosaics built from full-resolution (75 m/pixel) strips, covering key terrains of Venus. Each mosaic is 7168 lines by 8192 samples, stored as 56 framelets of 1024 by 1024 pixels."
  data_details: "A PDS4 version restores the mosaics from the original CD-ROM sets."
  urls:
    primary: "https://pds.nasa.gov/ds-view/pds/viewDataset.jsp?dsid=MGN-V-RDRS-5-MIDR-FULL-RES-V1.0"
    secondary:
      - {label: "PDS4 user guide", url: "https://pds-geosciences.wustl.edu/mgn/urn-nasa-pds-magellan_midr/document/midr_userguide.pdf"}
  caveats: ""
```

## 6. Report template

Use this when asked to produce a mapping report. Fill from section 5. Keep the order ENG, MAT, TEL, SCI or follow the user's order.

```markdown
# <Project name> - NASA Real-World Data Mapping

## 1. Data-Producing Instruments (Science and Telemetry)
### <Category>, tier <n>
* **<game_part>** (`<id>`)
   * Real-World Analog/Dataset: <analog>
   * Description: <description> (one or two sentences, paraphrased)
   * Fit: <fit>   Caveat: <caveats if any>
   * Source: <urls.primary>

## 2. Structural and Propulsion Hardware (Engines and Tanks)
Explain once that inert hardware has no datasets on data.nasa.gov or in the PDS.
* **<game_part>** (`<id>`)
   * Real-World Analog: <analog>
   * NTRS Records: <id and url for each>
   * NTRS Search Terms: <ntrs_search_terms>
   * Documentation Type: <documentation_type>

## 3. Accountability
Table of parts in input versus parts mapped per category. Totals must be 7, 6, 11, 5 = 29.
```

## 7. Portals

```yaml
portals:
  - {name: "NASA Open Data Portal", url: "https://data.nasa.gov/dataset/", use: "catalog records for harvested PDS and DAAC datasets"}
  - {name: "PDS Atmospheres Node", url: "https://atmos.nmsu.edu", use: "MSL REMS, Galileo Probe ASI"}
  - {name: "PDS Geosciences Node", url: "https://pds-geosciences.wustl.edu", use: "Magellan, MOLA"}
  - {name: "PDS Small Bodies Node", url: "https://sbn.psi.edu", use: "NEAR NLR, OSIRIS-REx OLA, asteroid radar"}
  - {name: "PDS Planetary Plasma Interactions Node", url: "https://pds-ppi.igpp.ucla.edu", use: "MSL RAD, MAVEN MAG"}
  - {name: "NAIF SPICE", url: "https://naif.jpl.nasa.gov", use: "attitude C-kernels"}
  - {name: "NASA Earthdata", url: "https://www.earthdata.nasa.gov", use: "ICESat-2, SORCE, DSCOVR catalog records"}
  - {name: "JPL SSD", url: "https://ssd-api.jpl.nasa.gov", use: "small-body radar astrometry"}
  - {name: "NASA Technical Reports Server", url: "https://ntrs.nasa.gov", use: "engine and tank engineering reports"}
```

## 8. Known gaps and corrections

```yaml
gaps:
  - {ids: ["ENG-2-02", "ENG-2-03", "ENG-3-01"], note: "Proprietary vehicles (Rutherford, Merlin, Orion 50S XL) have no vehicle-specific NTRS records. Class-level analogs used."}
  - {ids: ["MAT-2-01"], note: "No small Al-Li tank record found; Shuttle SLWT documents used."}
  - {ids: ["TEL-1-02", "TEL-1-04", "TEL-2-01", "TEL-3-03"], note: "Engineering subsystems with no real science archive. Loose analogs."}
  - {ids: ["TEL-1-05", "TEL-2-02", "TEL-3-04"], note: "Analogs are laser ranging or ground-based radar, not spacecraft radar."}
  - {ids: ["ENG-2-03"], note: "NTRS 20000064017 is known by id only; no URL was retrieved."}
corrections:
  - {id: "ENG-1-01", was: "GP-B used nitrogen cold-gas thrusters", now: "GP-B used helium boil-off gas"}
  - {id: "MAT-2-01", was: "cited Orion structure as an analog", now: "removed as unsupported"}
  - {id: "ENG-3-01", was: "search terms only", now: "no Orion 50S XL record in NTRS; mapped to five-segment booster class"}
  - {id: "TEL-1-04", was: "generic engineering telemetry", now: "Mars Pathfinder Rover Engineering data set"}
  - {scope: "all dataset records", was: "search instructions", now: "exact URLs returned by search"}
```
