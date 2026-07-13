---
type: Purpose
title: mise-agents
description: Manage reproducible versions of AI agents, skills, and plugins through mise.
---

# Purpose

Enable mise users to discover, install, select, update, and uninstall versioned AI agents, skills, and plugins through mise's standard tool-management workflow, making agent environments declarative and reproducible.

# Sub-purposes

- Manage agent releases as versioned tools.
- Manage skill releases through the Skills CLI ecosystem (`npx skills`).
- Manage plugin releases alongside agents and skills.

# Boundaries

- Provides version lifecycle integration with mise; it does not define or execute agent behavior.
- Does not author or host upstream agents, skills, or plugins.
- Does not manage prompts, runtime sessions, credentials, or unrelated development tools.
