## Sandbox & approvals

For information about Codex sandboxing and approvals, see [this documentation](https://developers.openai.com/codex/security).

# Codex Security

<CtaPillLink
  href="https://chatgpt.com/plugins/share/676aca3811d54fa7bcdef5255236b3c4"
  label="Install plugin in ChatGPT"
  icon="external"
  class="mb-8 mt-2"
/>

For a prescriptive first local scan, start with the [Codex Security plugin
quickstart](https://learn.chatgpt.com/docs/security/plugin).

### Explore plugin use cases

- [Run a security scan](https://learn.chatgpt.com/docs/security/plugin/scans) for a repository or one scoped folder.
- [Run a deep security scan](https://learn.chatgpt.com/docs/security/plugin/deep-scans) when you need a more comprehensive scan and can wait longer for it to finish.
- [Review code changes](https://learn.chatgpt.com/docs/security/plugin/code-changes) before you merge a pull request or branch.
- [Triage a backlog](https://learn.chatgpt.com/docs/security/plugin/triage-backlog) when you have existing security findings to review.
- [Fix and verify findings](https://learn.chatgpt.com/docs/security/plugin/fix-findings) with bounded patches for approved findings.
- [Export or track findings](https://learn.chatgpt.com/docs/security/plugin/export-findings) as portable artifacts or approval-gated tracking destinations.
- [Write vulnerability reports](https://learn.chatgpt.com/docs/security/plugin/vulnerability-reports) from supplied findings, disclosure notes, source, and PoCs.
- [Propose security hardening](https://learn.chatgpt.com/docs/security/plugin/security-hardening) from scan results or other security evidence.
- [See what's new](https://learn.chatgpt.com/docs/security/plugin/changelog) in the Codex Security plugin.

The plugin runs in your Codex chat. Codex Security cloud scans connected
GitHub repositories through Codex cloud. For Codex sandboxing, approvals,
network controls, and admin settings, see [Agent approvals &
security](https://learn.chatgpt.com/docs/agent-approvals-security).

## Codex Security cloud

Codex Security cloud is currently in research preview. It scans connected
GitHub repositories for likely security issues.

It helps teams:

1. **Find likely vulnerabilities** by using a repo-specific threat model and real code context.
2. **Reduce noise** by validating findings before you review them.
3. **Move findings toward fixes** with ranked results, evidence, and suggested patch options.

## How Codex Security cloud works

Codex Security scans connected repositories commit by commit.
It builds scan context from your repo, checks likely vulnerabilities against that context, and validates high-signal issues in an isolated environment before surfacing them.

You get a workflow focused on:

- repo-specific context instead of generic signatures
- validation evidence that helps reduce false positives
- suggested fixes you can review in GitHub

## Codex Security cloud access and prerequisites

Codex Security cloud works with connected GitHub repositories through Codex
cloud. If a repository isn't visible, confirm the repository is available in your
Codex cloud workspace or contact your OpenAI account team.

## Related docs

- [Codex Security plugin quickstart](https://learn.chatgpt.com/docs/security/plugin) walks through installation and a first local scan.

# Codex Security plugin quickstart

Codex Security is a security-review plugin for Codex that scans your code for
vulnerabilities, validates plausible findings, and presents evidence and
remediation guidance in a reviewable workspace. Use it to find security issues
in code you own or have authorization to assess before they reach production.

This quickstart takes you through one recommended first run: an ordinary,
read-only scan of a local repository in Codex.

This page covers the plugin that runs in a local Codex chat. To scan a
connected GitHub repository in Codex cloud, see [Codex Security cloud
setup](https://learn.chatgpt.com/docs/security/setup).

## Install the plugin

1. In your terminal, go to the repository you want to assess and start Codex:

   ```bash
   codex
   ```

2. Enter `/plugins`, search for **Codex Security**, and select **Install
   plugin**.
3. Enter `/new` to start a new chat for the repository.

## Run your first scan

For the best scan quality, use `gpt-5.6-sol`
with `xhigh` reasoning effort.

<WorkflowSteps variant="headings">

1. Ask for an ordinary scan

   Send this prompt in the new chat:

   ```text
   Run a Codex Security scan on this repository.
   ```

2. Let the scan finish

   Codex runs the scan in the terminal without opening a setup workspace. Keep
   the task running until Codex reports completion. If Codex identifies a
   configuration limitation, review the exact limitation and proposed change
   before allowing it to update your configuration.

3. Review the result

   Review the summary in the terminal, then open the generated `report.md` for
   the complete result.

</WorkflowSteps>

## What the scan creates

Every completed scan reports a summary in the terminal and creates the files
below.

- `report.md`, the primary readable entry point to the scan results.
- `findings/<slug>/`, with one detailed vulnerability report per reportable
  finding and supporting proof-of-concept files when available.
- `hardening/`, with a structural hardening portfolio and supporting proposals
  or diagrams when the scan has reportable findings.
- Structured scan data in `scan-manifest.json`, `findings.json`, and
  `coverage.json` for automation and integrations. You normally don't need to
  open these files yourself.

Keep the full scan directory together when sharing or archiving results so the
links from `report.md` continue to work.

## Choose your next workflow

- [Run a standard or scoped scan](https://learn.chatgpt.com/docs/security/plugin/scans) when you want
  to scan a repository or one folder with the default workflow.
- [Run a deep scan](https://learn.chatgpt.com/docs/security/plugin/deep-scans) when you need a more
  comprehensive scan and can wait longer for it to finish.
- [Review code changes](https://learn.chatgpt.com/docs/security/plugin/code-changes) when the target is
  a pull request, commit, branch range, or working-tree patch.
- [Triage a backlog](https://learn.chatgpt.com/docs/security/plugin/triage-backlog) when you have
  existing security findings to review.
- [Fix and verify a finding](https://learn.chatgpt.com/docs/security/plugin/fix-findings) after you
  accept one finding for remediation.
- [Export or track findings](https://learn.chatgpt.com/docs/security/plugin/export-findings) when you
  need JSON, CSV, SARIF, an approval-gated Linear, GitHub, or Jira issue, or a
  private draft GitHub Security Advisory.
- [Write vulnerability reports](https://learn.chatgpt.com/docs/security/plugin/vulnerability-reports)
  when you want to turn supplied findings, disclosure notes, source, and PoCs
  into polished, self-contained reports.
- [Propose security hardening](https://learn.chatgpt.com/docs/security/plugin/security-hardening) when
  you want structural or architectural options based on scan results or other
  security evidence.

- [Codex Security cloud setup](https://learn.chatgpt.com/docs/security/setup) details setup, scanning, and findings review.
- [Improving the threat model](https://learn.chatgpt.com/docs/security/threat-model) explains how to tune scope, attack surface, and criticality assumptions.
- [Codex Security cloud FAQ](https://learn.chatgpt.com/docs/security/faq) covers common cloud product questions.
