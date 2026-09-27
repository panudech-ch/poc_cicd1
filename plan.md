# CI/CD Migration Plan — GitLab CI to GitHub Actions

## Context

`example-gitlab-ci.yml` is the reference pipeline from an existing production project
running on GitLab CI. This repository (`poc_cicd1`) is the proving ground: everything in
this plan is built and verified here first, then applied to the real project.

Target platform: **GitHub Actions**.
Scope order: **Android first, iOS after**.

---

## Gap Analysis

What the reference pipeline does versus what this repository has today.

| Capability | Reference (GitLab) | This repo | Phase |
|---|---|---|---|
| Environments | dev, uat, prod, live | dev, prod | 1 |
| Entry points | `main_dev/uat/prod.dart` | single `main.dart` | 1 |
| Build number | `CI_PIPELINE_ID` | none | 1 |
| Deploy tooling | Fastlane lanes | inline action in YAML | 2 |
| Google Play upload | `supply --track internal` | none | 2 |
| Trigger model | manual + schedule | branch push | 3 |
| Environment selector | `CD_ENV` dropdown | none | 3 |
| Test reports | JUnit, coverage, code quality | plain pass/fail | 4 |
| Notifications | `notification.sh` per deploy | none | 4 |
| iOS pipeline | all environments | none | 5 |
| Localization | `translate.sh` + publish API | not applicable | — |

Localization is specific to the reference project and is out of scope here.

---

## Phase 1 — Foundation

Everything downstream depends on this phase.

### 1.1 Add the `uat` flavor

`android/app/build.gradle.kts` currently declares `dev` and `prod`. Add `uat` so the
repository matches the four environments the reference pipeline ships.

| Flavor | applicationId | App name |
|---|---|---|
| dev | `com.example.poc_cicd1.dev` | POC CICD Dev |
| uat | `com.example.poc_cicd1.uat` | POC CICD UAT |
| prod | `com.example.poc_cicd1` | POC CICD |

`live` in the reference pipeline reuses the `prod` flavor with a different Firebase tester
group, so it needs no flavor of its own.

### 1.2 Split entry points

The reference builds with `-t lib/main_dev.dart`. Create one entry point per environment,
each wiring its own configuration and calling a shared `runApp`.

```
lib/
  main_dev.dart
  main_uat.dart
  main_prod.dart
  app.dart          shared widget tree
  config/env.dart   per-environment values (API base URL, flags)
```

`lib/main.dart` is removed once the three entry points exist.

### 1.3 Build number

Firebase App Distribution and the Play Store both reject a build number that has already
been used. The reference pipeline passes `--build-number ${CI_PIPELINE_ID}`.

GitHub Actions equivalent: `${{ github.run_number }}`, monotonically increasing per
workflow. A workflow that must share numbering across workflows uses `github.run_id`
instead.

### Deliverable

`flutter build apk -t lib/main_dev.dart --flavor dev --release --build-number N` produces a
signed APK whose package name, app name, and build number are all correct.

---

## Phase 2 — Fastlane for Android

The reference pipeline keeps deployment logic in `Fastfile`, not in the CI file. The CI
step is only `bundle exec fastlane <lane>`. Adopting the same split means the real project
can move between CI platforms without rewriting its deployment steps, and any developer can
run the exact same deploy from their own machine.

### 2.1 Structure

```
android/
  Gemfile               pins fastlane
  fastlane/
    Fastfile            lane definitions
    Appfile             package name, Firebase app ids
```

### 2.2 Lanes

| Lane | Builds | Destination |
|---|---|---|
| `dev_firebase` | dev release APK | Firebase, group `testers` |
| `uat_firebase` | uat release APK | Firebase, group `uat-testers` |
| `prod_firebase` | prod release APK | Firebase, group `production` |
| `live_firebase` | prod release APK | Firebase, group `live` |
| `prod_play_internal` | prod release AAB | Google Play, internal track |

Each lane takes `build_number` as a parameter, mirroring the reference pipeline.

### 2.3 Required credentials

| Item | Purpose |
|---|---|
| Release keystore | signs every release build |
| Firebase service account JSON | App Distribution upload |
| Google Play service account JSON | Play Store upload (new) |

---

## Phase 3 — Workflows

### 3.1 Trigger model

The reference pipeline marks every deploy `when: manual` with `rules: if $CI_COMMIT_BRANCH`
— deployment is a deliberate action from any branch, never an automatic consequence of a
merge. Only the dev Android job additionally runs on `schedule`.

GitHub Actions has no direct equivalent to a manual job inside a running pipeline. The
closest match is `workflow_dispatch` with a choice input, which also reproduces the
reference's `CD_ENV` dropdown:

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, uat, prod, live]
      target:
        type: choice
        options: [firebase, play]
  schedule:
    - cron: '0 18 * * 1-5'   # dev nightly
```

This difference should be raised with the lead: GitLab gates a job inside an existing
pipeline, GitHub starts a new run. Where an approval gate is genuinely required, GitHub
Environments with required reviewers is the equivalent mechanism.

### 3.2 Workflow files

| File | Trigger | Replaces |
|---|---|---|
| `ci.yml` | PR and push to develop/main/release | reference `Unit Test` stage |
| `cd-android.yml` | `workflow_dispatch` + `schedule` | all Android deploy stages |
| `cd-ios.yml` | `workflow_dispatch` | all iOS deploy stages (phase 5) |

A single Android workflow parameterised by environment replaces the reference's separate
stage per environment. The stage-per-environment layout exists because GitLab renders
stages as pipeline columns; GitHub has no such constraint.

---

## Phase 4 — Reporting and notification

| Reference capability | GitHub Actions equivalent |
|---|---|
| JUnit report in MR | `dorny/test-reporter` |
| Cobertura coverage in MR diff | `irongut/CodeCoverageSummary` or Codecov |
| Code Quality report | `flutter analyze` output as workflow annotations |
| Golden image diff on MR | upload `test/**/failures/` as an artifact |
| `notification.sh` | Slack or Teams webhook step |

The reference marks its test job `allow_failure: true`, so a failing test never blocks the
pipeline. Whether to keep that behaviour is a decision for the lead — this plan defaults to
tests blocking the merge, which is the stricter and more common setting.

---

## Phase 5 — iOS

Deferred until the Android pipeline is complete and verified.

### Prerequisites

| Item | Note |
|---|---|
| Apple Developer Program | 99 USD per year, not yet obtained |
| Distribution certificate and profiles | managed through Fastlane `match` |
| App Store Connect API key | `.p8` file, for TestFlight upload |
| Bundle identifier | `com.example.*` is rejected by App Store Connect |

### Cost warning

GitHub-hosted macOS runners bill at 10x the Linux rate. The reference pipeline uses GitLab
macOS SaaS runners (`macos-m2`, `macos-14-xcode-15`). Expected iOS build minutes should be
estimated before this phase starts, and a self-hosted Mac runner compared against the
hosted rate.

---

## Outstanding items

Carried over from earlier work in this repository; phases 1 to 3 cannot be verified until
these are resolved.

| Item | Status |
|---|---|
| `KEYSTORE_BASE64` secret | corrupt — regenerate with `base64 -i release.jks \| tr -d '\n'` |
| `FIREBASE_APP_ID_DEV` secret | not yet created |
| Firebase apps for uat and prod | not yet created |
| Firebase tester groups | only `testers` exists |

---

## Sequencing

```
Phase 1  foundation        blocks everything
   |
Phase 2  fastlane          needs flavors and entry points
   |
Phase 3  workflows         needs lanes to call
   |
Phase 4  reporting         independent of 2 and 3, can run in parallel
   |
Phase 5  iOS               needs Apple account, highest cost
```

Phase 4 has no dependency on phases 2 and 3 and can be picked up whenever convenient.
