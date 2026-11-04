# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Swift 6, AppKit app shell (NSStatusItem, NSPanel, NSWindow, NSGlassEffectView) with SwiftUI content views hosted inside it, a WidgetKit extension, and the `CleanyCore` Swift package. Project generated with XcodeGen.

## Users

Developers on a MacBook running on battery. Mid-work, they notice the battery falling fast or the fans spinning and want to know which forgotten leftovers (booted iOS Simulators, Docker containers, dev servers, idle apps, runaway browser tabs) are burning CPU, then stop the idle ones without touching anything they still use.

## Product Purpose

Cleany shows what is draining the Mac's battery right now, split by cause, and stops the idle culprits in one tap. Success: the user learns the cause in under five seconds from the menu bar and gets battery life back without losing work.

## Positioning

Every item is judged on its own with conservative, explainable rules: anything uncertain counts as in use and is left alone. Each verdict shows its evidence ("why we think it's idle"). Cleany only warns on its own; it never stops anything by itself.

## Operating Context

Lives in the menu bar (glance + popover that does the whole job), a main window for the full checklist, a desktop widget, and a drain-warning notification with a "Clean up N idle" action. Used while coding, often on battery, in any lighting.

## Capabilities and Constraints

- Categories: Simulators, Containers (Docker Desktop, OrbStack, Colima), Dev servers, Apps (never pre-ticked), Browser tabs (read-only advice), Restart (advice only).
- Modes: Quick select (ticks everything idle) and Choose myself.
- Per-item "?" explanation, Keep (Always kept list), Stop / Stop anyway, Undo after a cleanup.
- Nothing shows as idle for the first 10–30 minutes after launch or wake: Cleany must watch first.
- No network, no analytics, no accounts. Not sandboxed (needs process and Docker access).
- The detection engine is derived from TheoInTech/CleanUp (MIT).

## Brand Commitments

- Name: Cleany.
- Mascot: a raccoon, known for "washing" its food with its paws. Appears as the app icon, in the menu bar, and in-app, reacting to the Mac's state.
- Liquid Glass (macOS 26 design language) is a binding user requirement.

## Evidence on Hand

No users, testimonials, benchmarks or press yet. Do not invent any.

## Product Principles

1. Never touch anything in use; uncertainty means in use.
2. Show the cause first, text second.
3. Every verdict explains itself.
4. Warn, never act alone.
5. Friendly, never alarming: the raccoon helps, it doesn't scold.
