# Repository workload v1

This folder proposes the execution contract for ProductZero's first development
loop. It is versioned with the product repository, not compiled into Factory.
It does **not** implement a worker, claim an issue, authorize tools, or run models.
The installed worker must explicitly support this contract before using it.

## What lives where

| Location | Owns |
| --- | --- |
| Factory/Cosmos | Line registration, source/issue repositories, connection references, required issue labels, approved policy/limits, plant assignment, mission snapshots, claims and results. |
| This folder | Agent instructions, the supported workflow, requested commands/limits and expected outputs. |
| Installed workbench | Repository/workload retrieval, local policy, readiness checks, SDK sessions, verification, hard stop and authorized publication. |

This is a **repository workload**, not a replacement for the existing Factory
[production-line product/method metadocument](https://github.com/chieftn/softwarePlant/blob/daf3d5bd5f1f2241c930d8d3399f76cc719df4c0/schemas/production-line.schema.json)
or the service's registered line definition. Those describe different ownership
boundaries. `schemaVersion: "1"` identifies this execution contract;
`version: "1.0.1"` is its authoring version. Neither replaces a pinned Git commit.

## Files

- `workload.json`: the entry point resolved beneath Factory's configured
  workload folder (`productionLine`).
- `workload.schema.json`: the local JSON Schema for the proposed v1 contract.
- `agents/implementation.md`: Implementation instructions.
- `agents/alignment.md`: independent, read-only Alignment instructions.
- `Validate-Workload.ps1`, `tests/`: authoring validation,
  not runtime bootstrap or a product dependency.

The worker must pin the manifest, schema and instruction files from the same
source/workload commit and retain their digest in the frozen mission snapshot.
It must reject unsupported versions, fields, workflows, invalid paths and missing
instructions. Do not follow an arbitrary remote `$schema`, download executable
extensions, or fetch newer instructions partway through a mission.
The repository schema is an authoring aid; the installed worker must enforce
its supported contract and permissions independently, not trust a changed
schema to grant capabilities.
Do not put credentials in this folder, command arguments or agent outputs.

## The first workflow

```text
approved claimed issue
  -> Implementation
  -> independent verification of candidate commit
  -> Alignment of that same commit
       pass    -> checked candidate and evidence
       revise  -> Implementation, if budget remains
       blocked -> report the prerequisite/product decision; do not claim success
```

1. The service supplies one frozen, approved mission and an owned claim.
2. The worker prepares the isolated workspace and runs approved preparation
   commands once. Implementation runs in its own SDK session and returns a candidate.
3. The worker runs the configured verification commands, recording their actual
   exit codes, output/evidence references and the candidate commit. Failed checks
   return actionable findings to Implementation within the same budget.
4. Alignment gets a separate, fresh SDK session for each candidate, with frozen
   requirements, the exact diff and independent evidence. It has read-only
   workspace access and cannot implement, execute commands or publish.
5. Blocking findings return to Implementation; unresolved scope or prerequisites
   stop automatic retry. A pass is valid only for the reviewed commit with
   complete verification. No edits are allowed after verification/alignment
   without evaluating the changed candidate again.

An iteration is one Implementation pass, independent verification and, when
checks pass, Alignment. The configured maximum is three Implementation passes,
not three unlimited loops per agent. The 30-minute timeout covers the whole run,
including preparation, sessions and verification. The worker intersects these
requested limits with the service-approved limits and remaining mission budget;
a transport retry does not reset them. Reuse no SDK conversation across missions.
This is one supported sequential loop, not an arbitrary workflow graph, plugin
system or scheduler.

## Commands and current blocker

This repository currently contains no product project, package manifest, build or
test suite. Therefore both command lists are empty. An empty preparation list
can be valid; an empty **project verification** list must block execution.
Validating this folder is not sufficient verification of a future product change.
Do not choose a language/framework or invent build commands to hide that gap.

Once the product stack and checks are agreed, add actual preparation/verification
commands to `workload.json` and review that revision before enabling execution.
Each command specifies a bare `executable`, an `arguments` array, a
repository-root-relative `workingDirectory` (`.` for the root), and a positive
`timeoutSeconds`. Arguments are passed directly, not concatenated into a shell
string. The worker must verify supported executable/tool availability, approved
arguments and effects, directory containment including links, and remaining
budget before invoking a command. Schema validity is not command authorization.

The worker's readiness gate also requires the claimed repository/workload,
supported schema/workflow, service-owned GitHub and Copilot authentication,
workspace access, effective execution permissions and contact/stop controls.
Factory enrollment alone supplies none of the GitHub/Copilot credentials.
Alignment's requested read-only profile must be enforced by the SDK/tool adapter,
not merely by these instructions.

## Output and publication

Retain the candidate commit and changed paths, frozen mission/workload identities,
verification commands/exit codes/evidence, and the candidate-specific alignment
report. Record failures and blockers explicitly; agent prose is not a passed
check or proof that a PR exists.

A linked **draft PR** is a subsequent worker operation only when the mission,
server policy and local policy authorize publication. Preserve the resulting PR
reference and reconcile an uncertain push/PR response before retrying. Do not
automatically merge, release, or close the issue as accepted.

`workflow.completionCriterion` is required and supports only
`pull_request_merged`. A checked candidate, published PR or human approval alone
does not complete the mission. Factory must verify that the exact owned PR and
candidate were merged, and confirm prior worker termination before the next
issue can be claimed. A PR closed without merging retains ownership and requires
reconciliation; it is not successful completion. Human review/merge waiting uses
the fixed mission deadline, not a new execution budget.

## Revocation and stopping

Plant line removal/replacement or device membership revocation invalidates the
old execution configuration. On discovery, stop accepting work and terminate
owned SDK/command processes, including preparation or in-flight work. Also stop
at the run budget or bounded control-contact deadline.

Persist the interrupted mission journal and evidence. A stop request is not proof
of termination. Retain claim ownership while process state or publication effects
are uncertain, report attention-required state and reconcile rather than replay.
Do not apply a new plant's workload while old work is unresolved. Graceful quiesce
is deferred; v1 does not drain an active mission as its unassignment behavior.

## Validate this definition

Use PowerShell 7.4 or newer. No package installation is required:

```text
pwsh -File .\productionLine\Validate-Workload.ps1
pwsh -File .\productionLine\tests\Test-Workload.ps1
```

On Linux, use forward slashes in these commands.
The validator checks the local schema, manifest and referenced instructions.
It deliberately reports definition validity separately from project readiness.
`pwsh -File .\productionLine\Validate-Workload.ps1 -RequireProjectVerification` fails for this
initial definition with the explicit missing-project-verification blocker.
Even after that check passes, it does not prove worker prerequisites or authority.
These are local authoring checks, not product execution or worker readiness
certification. CI automation is not included in this initial contract.
