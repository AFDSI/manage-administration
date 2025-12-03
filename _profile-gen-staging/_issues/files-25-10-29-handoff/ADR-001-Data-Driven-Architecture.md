# Architecture Decision Record: Data-Driven Configuration Architecture

**ADR Number:** 001  
**Status:** Accepted  
**Date:** 2025-10-27  
**Decision Makers:** Development Team  
**Technical Context:** amp.dev, profile-generator, and future projects

---

## Context

We are building multilingual, cross-platform development tools and websites that must:
- Support multiple natural languages (en-US, es, fr, pt-BR, etc.)
- Work across platforms (Windows, macOS, Linux/WSL)
- Allow configuration without code changes
- Enable rapid iteration and customization
- Support build-time code generation

**Inspiration:** Windows Terminal's JSON-driven configuration demonstrated the power of separating logic from data.

**Current implementations:**
- Profile Generator: PowerShell logic + YAML configuration
- amp.dev: Node/Python/Grow build pipeline + multiple content formats

---

## Decision

We adopt a **Data-Driven Configuration Architecture** pattern for all projects, consisting of three distinct layers:

### 1. Immutable Logic Layer
**Contains:** Application code, processing algorithms, build tools  
**Language:** PowerShell, Python, JavaScript, etc.  
**Change Frequency:** Low (only for bugs or new features)  
**Examples:**
- `profile-build.ps1` (generator logic)
- `unix_builder.sh` (template processor)
- Gulp tasks (build orchestration)
- Python processors (content transformation)

### 2. Mutable Data Layer
**Contains:** Configuration, content, translations, environment variables  
**Format:** YAML, JSON, JSON-LD, Markdown, .po files  
**Change Frequency:** High (daily developer/content changes)  
**Examples:**
- `profile-values.yaml` (configuration)
- `profile-helpers-en.yaml` (content)
- `*.po` files (translations)
- `amp-dev-config.yaml` (site configuration)
- Environment-specific configs

### 3. Generated Output Layer
**Contains:** Profiles, websites, compiled assets  
**Generated:** By build process  
**Change Frequency:** Automatic (on build)  
**Examples:**
- `profile.generated.ps1` (from generator)
- `.bashrc.generated` (from templates)
- Built website (from amp.dev sources)

---

## Architectural Principles

### Principle 1: Separation of Logic and Data

**Rule:** Logic and data must never be mixed.

```
❌ ANTI-PATTERN:
function Get-Welcome {
    return "Welcome to the development environment"
}

✅ CORRECT PATTERN:
function Get-Welcome {
    param($config)
    return $config.messages.welcome
}
```

**Rationale:** 
- Enables i18n without code changes
- Allows configuration per environment
- Facilitates testing (inject test data)

---

### Principle 2: No Human-Readable Strings in Code

**Rule:** ALL user-facing text must be externalized.

**Scope includes:**
- Error messages
- Log messages
- UI text
- Help documentation
- Build output messages
- Status messages

```
❌ ANTI-PATTERN:
Write-Error "Configuration file not found"
console.log("Building website...")
print("Error: Invalid JSON")

✅ CORRECT PATTERN:
Write-Error (Get-Message 'errors.config_not_found')
console.log(i18n.t('build.messages.starting'))
print(_(gettext('errors.invalid_json')))
```

**Rationale:**
- Internationalization support from day one
- Consistent messaging across application
- Easy to update messages without code changes
- Enables A/B testing of messaging

---

### Principle 3: Configuration-Driven Behavior

**Rule:** Application behavior should be configurable without code modification.

**Configurable aspects:**
- Paths and directories
- Feature flags
- Environment-specific settings
- Platform-specific values
- User preferences
- Build options

```yaml
# Good: Platform-specific paths in configuration
workspace:
  win: "E:\\users\\gigster\\workspace"
  wsl: "/mnt/e/users/gigster/workspace"
  mac: "/Users/gigster/workspace"

# Good: Feature flags
features:
  experimental_mode: false
  debug_logging: true
  api_key_validation: true
```

**Rationale:**
- Deploy same code to multiple environments
- Enable/disable features without recompiling
- A/B test features with configuration
- Easier QA testing

---

### Principle 4: Build-Time Binding

**Rule:** Configuration and content should be bound at build time, not runtime (where practical).

**Build process:**
```
1. Read configuration files (YAML/JSON)
2. Read content files (MD/templates)
3. Read translations (.po files)
4. Process/transform/bind
5. Generate output (profiles/websites/assets)
6. Output is ready for deployment
```

**Benefits:**
- Early error detection (fail at build, not production)
- Optimized output (pre-processed)
- Version control includes configuration
- Clear rebuild trigger (config change → rebuild)

**Examples:**
- Profile Generator: YAML → Generated PS1/Bash files
- amp.dev: Templates + Data → Static HTML
- Sass: SCSS + variables → CSS
- Webpack: Modules + config → Bundle

---

### Principle 5: Schema Validation

**Rule:** All configuration files must have schemas and be validated.

**Required:**
- JSON Schema for JSON files
- YAML validation against schema
- Type checking in code that reads config
- Build fails on invalid configuration

```yaml
# profile-values.yaml should have schema:
# - Required fields defined
# - Type constraints enforced
# - Enum values validated
# - Path formats verified
```

**Rationale:**
- Catch errors early (build time, not runtime)
- Self-documenting configuration
- IDE autocomplete support
- Prevents deployment of invalid configs

---

## Implementation Guidelines

### For New Projects:

1. **Start with configuration design**
   - Define what needs to be configurable
   - Create YAML/JSON schema
   - Document all configuration options

2. **Implement i18n from start**
   - Set up .po file structure
   - Create message extraction process
   - Never hard-code strings

3. **Build pipeline first**
   - Define build inputs and outputs
   - Create build/regeneration script
   - Document build process

4. **Separate by file type:**
   ```
   config/          # Configuration files
   content/         # Content files
   locales/         # Translation files
   templates/       # Template files
   src/             # Source code (logic only)
   build/           # Build scripts
   output/          # Generated files (gitignored)
   ```

---

### For Existing Projects (Migration):

**Phase 1: Extract Configuration**
- Identify hard-coded values
- Move to configuration files
- Update code to read from config

**Phase 2: Externalize Strings**
- Audit codebase for user-facing text
- Extract to i18n files
- Update code to use i18n functions

**Phase 3: Build Pipeline**
- Document manual steps
- Automate with build script
- Add validation checks

**Phase 4: Schema & Validation**
- Create schemas for configs
- Add validation to build
- Document configuration options

---

## Standards & Tools

### Configuration Formats

| Type | Format | Schema | Rationale |
|------|--------|--------|-----------|
| Application Config | YAML | JSON Schema | Human-readable, comments allowed |
| API/Data | JSON | JSON Schema | Standard, universally supported |
| Translations | .po (gettext) | gettext format | Industry standard for i18n |
| Content | Markdown | Frontmatter + MD | Human-friendly authoring |
| Structured Data | JSON-LD | Schema.org | Semantic web compliance |

### Required Tools

**Python Projects:**
- `gettext` - Translation extraction/compilation
- `pyyaml` - YAML parsing
- `jsonschema` - Schema validation

**Node Projects:**
- `i18next` - Internationalization
- `js-yaml` - YAML parsing  
- `ajv` - JSON Schema validation

**PowerShell Projects:**
- `powershell-yaml` - YAML parsing
- Custom validation functions
- Template-based generation

---

## Examples

### Example 1: Profile Generator (Current Implementation)

**Configuration Layer:**
```yaml
# profile-values.yaml
platform:
  windows:
    header: "Windows Development Environment"
    home: "C:\\Users\\Owner"
```

**Logic Layer:**
```powershell
# profile-build.ps1
$header = Get-PropertyValue $config.platform.windows 'header' 'Environment'
```

**Output Layer:**
```powershell
# profile.generated.ps1
Write-Host "Windows Development Environment"
```

✅ **Adheres to principles:** Logic separated, configuration drives output.

---

### Example 2: amp.dev Error Messages (Proposed)

**Current (Anti-pattern):**
```python
if not file.exists():
    print("Error: File not found")
```

**Proposed (Correct pattern):**

**Translation file (locales/en_US/errors.po):**
```
msgid "errors.file_not_found"
msgstr "Error: File not found at {path}"
```

**Code:**
```python
if not file.exists():
    print(_(gettext('errors.file_not_found').format(path=filepath)))
```

**Translation file (locales/es/errors.po):**
```
msgid "errors.file_not_found"
msgstr "Error: Archivo no encontrado en {path}"
```

---

### Example 3: Build Messages (Proposed)

**Configuration (build-messages.yaml):**
```yaml
build:
  starting: "Building {project_name}..."
  processing: "Processing {file_count} files..."
  complete: "Build complete in {duration}s"
  
errors:
  sass_compile: "Sass compilation failed: {error}"
  missing_config: "Configuration file missing: {path}"
```

**Code:**
```javascript
const msg = config.build.starting.replace('{project_name}', projectName);
console.log(msg);
```

---

## Consequences

### Positive

✅ **Internationalization Ready**
- Support multiple languages without code changes
- Add languages by adding .po files

✅ **Environment Flexibility**  
- Same code runs in dev/staging/prod
- Configuration defines environment

✅ **Rapid Iteration**
- Change behavior via config, not code
- No recompilation needed

✅ **Clear Separation**
- Developers focus on logic
- Content editors focus on content
- Translators focus on translations

✅ **Version Control Benefits**
- Configuration changes tracked separately
- Easy to see what changed
- Easy to roll back configs

---

### Negative (Trade-offs)

⚠️ **Build Complexity**
- Requires build/generation step
- Build script must be maintained
- Dependencies between files

⚠️ **Learning Curve**
- Team must understand architecture
- New developers need onboarding
- More files to manage

⚠️ **Debugging Challenges**
- Output is generated (not directly edited)
- Must trace from config → output
- Requires understanding of build

**Mitigation:**
- Comprehensive documentation
- Build error messages reference config
- Generated files include source comments
- Regular team training

---

### Neutral

📊 **More Files**
- Configuration files
- Translation files
- Template files
- Schema files

This is neither good nor bad - it's the nature of separation. Benefits outweigh the organizational overhead.

---

## Compliance

### New Projects

✅ **Required from day one:**
- Configuration in YAML/JSON
- No hard-coded strings
- Build script for generation
- Schema validation
- i18n structure (even if only en-US initially)

### Existing Projects

📋 **Migration checklist:**
- [ ] Audit for hard-coded strings
- [ ] Extract to configuration files
- [ ] Set up i18n infrastructure
- [ ] Create build pipeline
- [ ] Add schema validation
- [ ] Document configuration
- [ ] Update team processes

---

## Related Decisions

**Related ADRs:**
- ADR-002: Internationalization Strategy (TBD)
- ADR-003: Build Pipeline Standards (TBD)
- ADR-004: Configuration Schema Standards (TBD)

**Supersedes:**
- None (first ADR)

**Superseded by:**
- None (current)

---

## Review & Updates

**Review Schedule:** Quarterly  
**Next Review:** 2025-01-27  
**Owned by:** Architecture Team  
**Status:** Accepted

**Change Log:**
- 2025-10-27: Initial ADR creation
- Future updates will be recorded here

---

## References

**Inspiration:**
- Windows Terminal architecture (JSON-driven configuration)
- The Twelve-Factor App (configuration in environment)
- gettext internationalization (standard i18n approach)

**Further Reading:**
- [The Twelve-Factor App - Config](https://12factor.net/config)
- [GNU gettext Manual](https://www.gnu.org/software/gettext/manual/)
- [JSON Schema](https://json-schema.org/)
- [Windows Terminal Settings Schema](https://aka.ms/terminal-profiles-schema)

---

## Appendix A: Quick Reference

### For Developers: "Where Does It Go?"

| What | Where | Format |
|------|-------|--------|
| Paths/URLs | config.yaml | YAML |
| Feature flags | config.yaml | YAML |
| User messages | locales/*.po | gettext |
| Error messages | locales/*.po | gettext |
| Content | content/*.md | Markdown |
| Processing logic | src/*.{py,js,ps1} | Source code |
| Build scripts | build/*.{py,js,ps1} | Source code |

### Golden Rule

> **If a human will read it, it goes in a data file, not source code.**

---

**END OF ADR-001**
