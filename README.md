# mise-php

A [mise](https://mise.jdx.dev) backend plugin for precompiled PHP binaries built with
[StaticPHP](https://static-php.dev). It installs PHP and Composer without compiling source code or installing system
packages.

## Requirements

- mise with experimental backend plugins enabled
- Linux or macOS
- `x86_64` or `aarch64`
- `sha256sum` or `shasum`

## Install

Enable experimental backend plugins and install `mise-php` as the `php` plugin:

```bash
mise settings experimental=true
mise plugins install php https://github.com/edram/mise-php
```

Install the PHP CLI with the `common` extension channel:

```bash
mise use php:cli-common@8.5
php -v
composer --version
```

Select another channel through the tool name:

```bash
mise use php:cli-laravel@8.5
mise use php:cli-minimal@8.5
```

Linux builds use a fully static musl binary by default. Append `-gnu` to install the glibc 2.17-compatible build:

```bash
mise use php:cli-laravel-gnu@8.5
```

GNU builds are available on Linux only. On macOS, use the channel name without a runtime suffix.

Fuzzy versions resolve through mise, so `@8.5` selects the latest published `8.5.x` build. Exact versions and
`@latest` are also supported:

```bash
mise use php:cli-common@8.5.9
mise use php:cli-common@latest
```

The selected channel and optional runtime are stored in `mise.toml` as part of the tool name:

```toml
[tools]
"php:cli-laravel-gnu" = "8.5"
```

## Update

Update the plugin itself to the latest commit:

```bash
mise plugins update php
```

## Channels

| Channel | GNU glibc | Purpose |
| --- | --- | --- |
| `common` | 2.17+ | CLI build with database, network, image, XML, archive, and Redis support |
| `laravel` | 2.25+ | Herd-inspired CLI build for Laravel applications |
| `minimal` | 2.17+ | Upstream minimal CLI build with additional PHP extensions for Composer |

The `minimal` channel adds `openssl` for HTTPS downloads and `zip` for extracting ZIP packages. All other extensions
match StaticPHP's upstream minimal build.

The `laravel` channel follows [Laravel Herd's included extension set](https://herd.laravel.com/docs/macos/technology/php-extensions).

Channel definitions live in [`channels.json`](channels.json). Each entry contains the extensions, GNU glibc baseline,
and extra StaticPHP build options for that channel. When adding one, also expose its name in the build workflow's
`channel` options.

Only versions whose platform archive includes a GitHub-provided SHA-256 digest are returned:

```bash
mise ls-remote php:cli-common
```

## How installation works

The plugin reads published releases from [edram/mise-php](https://github.com/edram/mise-php/releases). Release tags
and assets use this contract:

```text
php-{version}-{sapi}-{channel}
php-{version}-{sapi}-{channel}-{platform}-{arch}.tar.gz
php-{version}-{sapi}-{channel}-linux-{arch}-gnu.tar.gz
```

For example:

```text
php-8.5.9-cli-common
php-8.5.9-cli-common-linux-x86_64.tar.gz
php-8.5.9-cli-common-linux-x86_64-gnu.tar.gz
```

During installation the plugin:

1. detects the platform and architecture through mise;
2. reads the archive's SHA-256 digest from the GitHub Releases API;
3. downloads and verifies the archive before extracting it;
4. installs PHP as `<install_path>/bin/php`;
5. verifies and installs Composer as `<install_path>/bin/composer`;
6. adds `<install_path>/bin` to `PATH` through `BackendExecEnv`.

Each archive must contain a single executable named `php` at its root.

Each PHP installation gets its own Composer executable. Composer configuration and cache continue to use Composer's
default global directories.

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
`php:cli-common` release, and executes PHP and Composer.

## License

[MIT](LICENSE)
