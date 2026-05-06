# Skill Registry — continua

Generated: 2026-05-05
Updated by: sdd-init

## Project Context
- **Stack**: Flutter (Dart), Supabase, Firebase, Deno Edge Functions
- **Registry Scope**: User-level + project-level skills applicable to this codebase

## Applicable Skills

### Code Quality
| Skill | Location | Trigger Context |
|-------|----------|-----------------|
| clean-code | `~/.agents/skills/clean-code/` | Universal — Dart/Flutter code quality, readability, SOLID principles |

### UI / Frontend
| Skill | Location | Trigger Context |
|-------|----------|-----------------|
| frontend-design | `~/.agents/skills/frontend-design/` | Building Flutter widgets, screens, UI polish, theming |

### Workflow & Collaboration
| Skill | Location | Trigger Context |
|-------|----------|-----------------|
| issue-creation | `~/.config/opencode/skills/issue-creation/` | Creating GitHub issues, bug reports, feature requests |
| branch-pr | `~/.config/opencode/skills/branch-pr/` | Creating pull requests, preparing changes for review |
| judgment-day | `~/.config/opencode/skills/judgment-day/` | Adversarial dual-review of code or specs |

### Meta / Tooling
| Skill | Location | Trigger Context |
|-------|----------|-----------------|
| find-skills | `~/.agents/skills/find-skills/` | Discovering or requesting new skills |
| skill-creator | `~/.config/opencode/skills/skill-creator/` | Creating new agent skills |
| skill-registry | `~/.config/opencode/skills/skill-registry/` | Updating this registry file |

## Not Applicable (Stack Mismatch)
The following user skills are installed but do **not** apply to this Flutter project:

- `angular-best-practices`, `angular-component`, `angular-forms`, `angular-http`, `angular-routing`, `angular-signals` — Angular-specific; this project uses Flutter.
- `go-testing` — Go/Bubbletea-specific; this project uses Dart.

## SDD Skills (Orchestrator-Managed)
The following SDD phase skills are available in the environment and invoked by the orchestrator:
- `sdd-init`, `sdd-explore`, `sdd-propose`, `sdd-spec`, `sdd-design`, `sdd-tasks`, `sdd-apply`, `sdd-verify`, `sdd-archive`, `sdd-onboard`

These are **not** loaded manually during coding; the orchestrator routes to them automatically.

## Missing Skills (Recommended)
Based on this project's stack, consider installing or creating:

- **Flutter/Dart best practices** — State management patterns, testing, performance
- **Flutter testing** — Widget testing, golden tests, integration tests with Patrol
- **Supabase/Dart patterns** — Edge function integration, RLS policies, real-time subscriptions
- **Firebase Cloud Messaging (Flutter)** — Push notification deep-dives, token management

## How to Update
Run `skill registry` or `update skills` to re-scan and refresh this file.
