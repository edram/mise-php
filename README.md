# mise-php

A [mise](https://mise.jdx.dev) backend plugin for precompiled PHP binaries built with
[StaticPHP](https://static-php.dev). It installs PHP without compiling source code or installing system packages.

## Requirements

- mise with experimental backend plugins enabled
- Linux or macOS
- `x86_64` or `aarch64`
- `sha256sum` or `shasum`

Windows builds are not available yet.

## Install

```bash
mise settings experimental=true
mise plugins install php https://github.com/edram/mise-php
```

Choose one extension preset:

```bash
mise use php:minimal@8.5
php -v
```

or:

```bash
mise use php:common@8.5
php -v
```

Do not activate both presets at the same time because both provide the `php` command.
Each preset becomes installable after a corresponding GitHub Release has been published.

Fuzzy versions resolve through mise, so `@8.5` selects the latest published `8.5.x` build. Exact versions and
`@latest` are also supported:

```bash
mise use php:minimal@8.5.9
mise use php:minimal@latest
```

In `mise.toml`:

```toml
[tools]
"php:minimal" = "8.5"
```

## Presets

| Tool | Purpose |
| --- | --- |
| `php:minimal` | Small CLI build with the extensions needed by common PHP tooling |
| `php:common` | Larger CLI build with database, network, image, XML, archive, and Redis support |

Only versions with both an archive and a checksum for the current platform are returned:

```bash
mise ls-remote php:minimal
mise ls-remote php:common
```

## How installation works

The plugin reads published releases from [edram/mise-php](https://github.com/edram/mise-php/releases). Release tags
and assets use this contract:

```text
php-{version}-{preset}
php-{version}-{preset}-{platform}-{arch}.tar.gz
php-{version}-{preset}-{platform}-{arch}.tar.gz.sha256
```

For example:

```text
php-8.5.9-minimal
php-8.5.9-minimal-linux-x86_64.tar.gz
php-8.5.9-minimal-linux-x86_64.tar.gz.sha256
```

During installation the plugin:

1. detects the platform and architecture through mise;
2. downloads the matching archive and checksum from GitHub Releases;
3. verifies the archive before extracting it;
4. installs the executable as `<install_path>/bin/php`;
5. adds `<install_path>/bin` to `PATH` through `BackendExecEnv`.

Each archive must contain a single executable named `php` at its root.

## Development

The repository follows the official
[mise backend plugin template](https://github.com/jdx/mise-backend-plugin-template) structure.

```bash
mise install
mise run format
mise run lint
mise run test
mise run ci
```

The integration test uses isolated mise data directories, links the local plugin as `php`, installs the latest
`php:minimal` release, and executes the installed binary.

## License

[MIT](LICENSE)
