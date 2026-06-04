<div align="center">

# ⚡ HAZARD RUSH

**A 1v1 AI-Driven Tactical Side-Scrolling Racing Game**

[![Godot 4.6.3](https://img.shields.io/badge/Godot-4.6.3-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)](https://godotengine.org)
[![GDScript](https://img.shields.io/badge/Language-GDScript-blue?style=for-the-badge)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![Academic](https://img.shields.io/badge/Purpose-Academic%20Only-red?style=for-the-badge)](#-disclaimer)
[![PUP CCIS](https://img.shields.io/badge/PUP-CCIS-gold?style=for-the-badge)](#-academic-context)

> Developed for **COSC 304: Introduction to Artificial Intelligence**
> Bachelor of Science in Computer Science — Group 6, BSCS 3-3
> Polytechnic University of the Philippines — June 2026

</div>

---

## 📖 Table of Contents

- [About the Game](#-about-the-game)
- [Features](#-features)
- [AI Algorithm Stack](#-ai-algorithm-stack)
- [Controls](#-controls)
- [Difficulty Levels](#-difficulty-levels)
- [Power-Ups & Hazards](#-power-ups--hazards)
- [Getting Started](#-getting-started)
- [Project Structure](#-project-structure)
- [Academic Context](#-academic-context)
- [Team](#-team)
- [References](#-references)
- [Disclaimer](#-disclaimer)

---

## 🎮 About the Game

**HAZARD RUSH** is a two-dimensional competitive tactical racing game developed as a final project requirement for COSC 304: Introduction to Artificial Intelligence. The game is structured as a **1v1 sprint** in which a human player races against an AI-controlled opponent across a side-scrolling **110-meter hurdle course**.

The primary objective is to **cross the finish line within 60 seconds** before the opposing runner. Both competitors must actively manage their **Kinetic Exertion Indicator (KEI)** — a normalized momentum resource — through rhythmic sprinting, precise obstacle evasion, and strategic use of power-ups and sabotage mechanics.

What distinguishes Hazard Rush from conventional racing games is its **AI opponent design**. Rather than relying on scripted behaviors or finite state machines, every decision the AI makes — from multi-step obstacle planning to split-second evasion reflexes to adversarial sabotage judgments — is driven entirely by **four classical search algorithms** drawn from _Russell and Norvig's Artificial Intelligence: A Modern Approach (4th ed., 2021)_. There is no machine learning, no neural network, and no reinforcement learning anywhere in the system.

> **Game Inspiration:** Structurally inspired by _Track and Field_ (Konami, 1983), which pioneered rhythm-based running mechanics. Hazard Rush modernizes that foundation with a resource-management layer, a three-category obstacle system, and an adversarial sabotage mechanic.

---

## ✨ Features

- **1v1 Competitive Racing** — Human vs. AI across a 110-meter side-scrolling hurdle course
- **KEI Momentum System** — A 60 fps normalized resource [0.0–1.0] that governs all movement for both competitors under identical rules
- **Three Obstacle Categories** — High Hurdles (jump), Low Obstacles (slide), and dynamically spawned Sabotage Hazards
- **8 Fruit Power-Ups** — Apple, Bananas, Cherries, Kiwi, Melon, Orange, Pineapple, Strawberry — each with distinct effects
- **Sabotage Mechanics** — EarthSpikeEffect (9-frame animated Area2D) and FireballProjectile (10-frame animated Area2D) hazards
- **Early Warning System (EWS)** — Visual warning indicators synchronized to incoming hazard position and type
- **Three Difficulty Tiers** — Easy, Medium, Hard with five independently scaled AI parameters
- **Animated Scene Transitions** — Shader-based TransitionManager with fade and loading spinner
- **Pixel-Art Aesthetic** — Custom BoldPixels font, sprite-sheet animations, and a parallax forest background

---

## 🤖 AI Algorithm Stack

The AI opponent uses **four classical search algorithms**, each assigned to a specific decision layer based on the structural characteristics of the problem that layer presents. The rationale for four distinct algorithms rather than one unified approach is that each decision type exhibits a fundamentally different problem structure.

| Priority | Algorithm | Update Rate | Decision Responsibility |
|:---:|---|---|---|
| **1** | **Greedy Best-First Search** | Every frame | Immediate evasion reflex for obstacles within the 0.40s–0.15s TTC window. Uses `f(n) = h(n)` only — past cost is irrelevant when an obstacle is milliseconds from contact. |
| **2** | **A\* Search** | Every 15 frames (~250ms) | Cost-optimal sprint and evasion plan across the next N static obstacles. Evaluation: `f(n) = g(n) + W×h(n)`. Returns `optimal_action_sequence[]`. |
| **2** | **IDA\* Search** *(fallback)* | On demand | Identical output to A\* with O(N) call-stack memory instead of O(bᴺ) frontier table. Activates on A\* `FAILURE` or when N ≤ 2. |
| **3** | **Minimax + Alpha-Beta Pruning** | Event-driven | Adversarial sabotage decision — `ACTIVATE` or `PASS` — at each trigger zone. 4-ply game tree; MAX = AI, MIN = Player. |


## 🕹️ How to Play

**1. Build Momentum (KEI)**
To run, you must rhythmically alternate between the **Sprint Left** and **Sprint Right** keys. A steady, consistent rhythm increases your Kinetic Exertion Indicator (KEI) and maximizes your speed. Mashing a single key or breaking the rhythm will penalize your momentum and slow you down.

**2. Clear the Hurdles**
As you race across the 110-meter course, you will encounter two types of static obstacles:
- **High Hurdles:** Time your **Jump** to leap over them safely.
- **Low Obstacles (Saws):** Hold the **Slide** key to pass underneath them.
*Failing to clear an obstacle results in a severe KEI penalty and a temporary stumble state.*

**3. Utilize Power-Ups**
Run into floating fruits scattered across the track to gain the upper hand. These can grant you shields, speed boosts, double jumps, or apply negative status effects to the AI opponent.

**4. Sabotage Your Opponent**
When you acquire a sabotage charge (via Orange power-ups), press the **Sabotage** key to spawn a devastating Earth Spike or Fireball in the AI's lane, forcing them to react perfectly or suffer a massive momentum crash.

**5. Cross the Finish Line**
Maintain your speed and beat the AI to the 110-meter mark before the 60-second timer expires!

---

## 🎮 Controls

| Action | Key(s) | Timing Constraint | Effect |
|---|---|---|---|
| **Sprint Left** | `A` | Alternate with D; max 200ms gap | Advances rhythm counter; increases KEI if correctly alternated |
| **Sprint Right** | `D` | Alternate with A; max 200ms gap | Advances rhythm counter; increases KEI if correctly alternated |
| **Jump** | `Space` / `↑` | 0.40s to 0.15s before contact | Initiates jump arc; clears High Hurdles |
| **Slide** | `Shift` / `↓` / `S` | Hold for at least 0.30s | Lowers hitbox; passes under Low Obstacles |
| **Conserve** | `C` / `Ctrl` | Hold; releases automatically | Caps speed at 60% of peak; reduces KEI decay to 0.003/frame |
| **Sabotage** | `F` / `Right Shift` | Within 0.30s trigger window | Spawns a Sabotage Hazard in the opponent's lane |

---

## 🎯 Difficulty Levels

The AI scales across three tiers by adjusting five parameters that govern output quality of its search algorithms.

| Parameter | Easy | Medium | Hard | Effect |
|---|:---:|:---:|:---:|---|
| A\* Lookahead Depth N | 2 | 3 | 5 | Higher N = wider planning horizon |
| A\* Heuristic Weight W | 1.5 | 1.2 | 1.0 | W=1.0 is full cost-optimal A\* |
| Reaction Delay (ms) | 250 | 150 | 80 | Simulates human-like response latency |
| Sprint Jitter Sigma (ms) | 40 | 20 | 8 | Gaussian noise applied to rhythm timing |
| Minimax Depth | 2 | 3 | 4 | Deeper tree = better sabotage decisions |

> At **Hard**, all parameters are fully optimal — the AI plans 5 obstacles ahead, reacts in 80ms, and searches a 4-ply minimax tree. At **Easy**, deliberate degradation simulates weaker opposition.

---

## 🍎 Power-Ups & Hazards

### Power-Up Fruits (8 Types)

Fruit sprites are located in `assets/environment/Fruits for PowerUps/`.

| Fruit | Asset |
|---|---|
| Apple | `Apple.png` |
| Bananas | `Bananas.png` |
| Cherries | `Cherries.png` |
| Kiwi | `Kiwi.png` |
| Melon | `Melon.png` |
| Orange | `Orange.png` |
| Pineapple | `Pineapple.png` |
| Strawberry | `Strawberry.png` |

### Sabotage Hazards

| Hazard | Type | Frames | Behavior |
|---|---|---|---|
| **EarthSpikeEffect** | Animated Area2D | 9 frames (0–5 active) | Spawned in opponent lane; bottom-anchored to floor; restricted to frames 0–5 |
| **FireballProjectile** | Animated Area2D | 10 frames | "fly" loop (frames 1–4); "hit" one-shot (frames 5–9); continues moving after impact |


## 🚀 Getting Started

### Prerequisites

| Requirement | Version |
|---|---|
| [Godot Engine](https://godotengine.org/download/) | **4.6.3 stable** |
| Operating System | Windows 10/11, macOS, Linux |

> ⚠️ The project targets **Godot 4.6.3** specifically. Other versions may cause compatibility issues.

### Installation

**1. Clone the repository**

```bash
git clone https://github.com/your-username/HAZARD-RUSH.git
cd HAZARD-RUSH
```

**2. Open in Godot**

- Launch the Godot 4.6.3 editor
- Click **Import** in the Project Manager
- Navigate to the cloned `HAZARD-RUSH/` folder
- Select `project.godot` and click **Import & Edit**

**3. Run the game**

- Press **F5** in the Godot editor, or click the **▶ Play** button
- The game will open to the main menu with the pre-game info overlay

> No external dependencies, plugins, or export templates are required to run the project in the editor.

---

## 📁 Project Structure

```
HAZARD-RUSH/
│
├── assets/
│   ├── backgrounds/              # Parallax background layers
│   ├── environment/
│   │   ├── Fruits for PowerUps/  # 8 fruit power-up sprites
│   │   └── Hurdles/
│   │       └── warning_incoming_hurdle/
│   │           └── spritesheet.png   # EWS warning indicator
│   ├── Logo/                     # Game logo (SVG)
│   └── new/                      # BoldPixels font, UI textures
│
├── scenes/
│   ├── main_menu.tscn            # Main menu (startup scene)
│   ├── pre_menu.tscn             # Intro/Credits/Disclaimer overlay
│   ├── main.tscn                 # Gameplay scene
│   ├── Main.tscn                 # Root scene container
│   └── ...                       # 18 additional scenes (racers, obstacles, UI)
│
├── scripts/
│   ├── main_menu.gd              # Main menu UI and navigation
│   ├── pre_menu.gd               # Pre-game overlay (CanvasLayer)
│   ├── game_state.gd             # GameState autoload singleton
│   └── ...                       # 26 additional scripts
│                                 # (AI planners, physics, collision, audio, etc.)
│
└── project.godot                 # Godot project configuration
```


## 🏫 Academic Context

| Field | Details |
|---|---|
| **Course** | COSC 304 — Introduction to Artificial Intelligence |
| **Program** | Bachelor of Science in Computer Science (BSCS) |
| **Section** | BSCS 3-3, Group 6 |
| **Instructor** | Prof. Ria A. Sagum, MCS |
| **College** | College of Computer and Information Sciences (CCIS) |
| **University** | Polytechnic University of the Philippines — Sta. Mesa, Manila |
| **Term** | June 2026 |

This project was developed solely as a **course requirement and academic demonstration** of classical AI search algorithms applied in a real-time game environment. It is not intended for commercial distribution.

---

## 👥 Team

| Name | Role |
|---|---|
| **Bacolor, James Clark C.** | Developer |
| **Caole, Stephanie J.** | Documenter |
| **Soriano, Shouma King J.** | Developer and Documenter |

---

## 📚 References

- Russell, S. J., & Norvig, P. (2021). *Artificial Intelligence: A Modern Approach* (4th ed., Global ed.). Pearson. http://lib.ysu.am/disciplines_bk/efdd4d1d4c2087fe1cbe03d9ced67f34.pdf

- Hart, P. E., Nilsson, N. J., & Raphael, B. (1968). A formal basis for the heuristic determination of minimum cost paths. *IEEE Transactions on Systems Science and Cybernetics, 4*(2), 100–107. https://doi.org/10.1109/TSSC.1968.300136

- Korf, R. E. (1985). Depth-first iterative-deepening: An optimal admissible tree search. *Artificial Intelligence, 27*(1), 97–109. https://doi.org/10.1016/0004-3702(85)90084-0

- Millington, I., & Funge, J. (2009). *Artificial Intelligence for Games* (2nd ed.). Morgan Kaufmann.

- Buckland, M. (2005). *Programming Game AI by Example*. Wordware Publishing.

- Shannon, C. E. (1950). Programming a computer for playing chess. *Philosophical Magazine, Series 7, 41*(314), 256–275.

---

## ⚠️ Disclaimer

This game was developed by **Group 6 of BSCS 3-3** as a project requirement for **COSC 304: Introduction to Artificial Intelligence**, under the Bachelor of Science in Computer Science (BSCS) program at the **College of Computer and Information Sciences (CCIS), Polytechnic University of the Philippines (PUP) — Sta. Mesa, Manila**. This project was created solely for **academic, educational, and demonstration purposes** and was presented during the course final requirement period in **June 2026**.

The AI opponent operates exclusively on **classical search algorithms** — no machine learning, neural networks, reinforcement learning, or trained models of any kind are present in this system.

This system is intended for **local academic evaluation only** and shall **not** be distributed publicly. The Polytechnic University of the Philippines does not endorse any product or commercial entity referenced within this project. Structural game design inspiration was drawn from **Konami's 1983 arcade release Track and Field**, acknowledged herein for academic attribution purposes only.

---

<div align="center">

**© 2026 · PUP CCIS · BSCS 3-3 Group 6 · Academic Use Only**

*Built with [Godot 4.6.3](https://godotengine.org) · Powered by Classical AI Algorithms*

</div>
