# mise-doppler-env

:warning: This was AI generated - Use at your own risk :warning:

A [mise](https://mise.jdx.dev) environment plugin for loading secrets from [Doppler](https://www.doppler.com/).

## Prerequisites

- [mise](https://mise.jdx.dev) installed
- [Doppler CLI](https://docs.doppler.com/docs/install-cli) installed and authenticated
- Run `doppler login` to authenticate

## Installation

Add the plugin to your `mise.toml`:

```toml
[plugins]
doppler-env = "https://github.com/brenix/mise-doppler-env"

[env]
_.doppler-env = { project = "your-project", config = "dev" }
```

### Enable Caching (Optional)

By default, secrets are fetched fresh from Doppler each time. To enable caching and avoid rate limits, set `cache_ttl` in seconds:

```toml
[env]
_.doppler-env = { project = "my-project", config = "dev", cache_ttl = 300 }  # 5 minutes
```

**If you enable caching**, add `.secrets.json` to your `.gitignore`:

```bash
echo ".secrets.json" >> .gitignore
```

### Configuration Priority

The plugin looks for Doppler configuration in this order:
1. Options in `mise.toml` (e.g., `{ project = "...", config = "..." }`)
2. Environment variables (`DOPPLER_PROJECT`, `DOPPLER_CONFIG`)
