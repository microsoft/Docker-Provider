# Skill: Documentation

## Overview
Maintain project documentation including release notes, developer guides, and README files for the Docker-Provider repository.

## Scope
- **Release notes**: `ReleaseNotes.md`
- **Developer documentation**: `Documentation/*.md`
- **Project README**: `README.md`
- **Dev guide**: `Dev Guide.md`
- **Chart READMEs**: `charts/*/README.md`
- **Release process**: `ReleaseProcess.md`

## Release Notes

### Format
Each release entry uses a version heading followed by a bullet list of changes:
```markdown
## <Date> - Version <X.Y.Z.Z> Release
- <Change description>
- <Change description> (#<PR number>)
- <Change description>
```

### Guidelines
- Add new entries at the **top** of `ReleaseNotes.md`.
- Use past tense ("Added", "Fixed", "Updated").
- Reference PR numbers where applicable.
- Group related changes together.
- Include version numbers for updated dependencies.

## Documentation Structure

### `Documentation/` Directory
Contains operational and developer guides. When adding new docs:
- Use descriptive filenames in PascalCase or kebab-case (match existing convention).
- Include a title as an H1 heading.
- Add a brief overview paragraph before diving into details.

### README.md
The top-level README provides project overview, setup instructions, and links. Keep it concise and link to detailed docs in `Documentation/`.

### Dev Guide.md
Developer onboarding and local development instructions. Update when build steps, prerequisites, or development workflows change.

## Writing Guidelines
- Use Markdown headers (`##`, `###`) for structure.
- Use fenced code blocks with language tags for commands and code snippets.
- Keep line lengths reasonable for readability in terminals and GitHub rendering.
- Use relative links for cross-references within the repo.
- Validate that all links point to existing files or URLs.

## Validation
- Review rendered Markdown on GitHub or with a local previewer.
- Check that relative links resolve correctly: `[text](./Documentation/file.md)`.
- Verify code examples are syntactically correct.
- Ensure no sensitive information (endpoints, keys, internal URLs) is included.

## Commit Convention
Freeform message describing the documentation change:
```
Update release notes for version 3.1.25 (#1234)
```
```
Add troubleshooting guide for log collection issues (#1235)
```
