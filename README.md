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

Install the PHP CLI with the default `common` extension channel:

```bash
mise use php:cli@8.5
php -v
composer --version
```

Select the `minimal` channel with mise tool options:

```bash
mise use 'php:cli[channel=minimal]@8.5'
```

Fuzzy versions resolve through mise, so `@8.5` selects the latest published `8.5.x` build. Exact versions and
`@latest` are also supported:

```bash
mise use php:cli@8.5.9
mise use php:cli@latest
```

The channel option is stored in `mise.toml` using the equivalent structured tool form:

```toml
[tools]
"php:cli" = { version = "8.5", channel = "minimal" }
```

## Update

Update the plugin itself to the latest commit:

```bash
mise plugins update php
```

## Channels

| Channel | Purpose |
| --- | --- |
| `common` | CLI build with database, network, image, XML, archive, and Redis support (default) |
| `minimal` | Upstream minimal CLI build with additional PHP extensions for Composer |

The `minimal` channel adds `openssl` for HTTPS downloads and `zip` for extracting ZIP packages. All other extensions
match StaticPHP's upstream minimal build.

Channel definitions live in [`channels.json`](channels.json). Each entry contains the extensions and extra StaticPHP
build options for that channel. When adding one, also expose its name in the build workflow's `channel` options.

Only versions whose platform archive includes a GitHub-provided SHA-256 digest are returned:

```bash
mise ls-remote php:cli
```

## How installation works

The plugin reads published releases from [edram/mise-php](https://github.com/edram/mise-php/releases). Release tags
and assets use this contract:

```text
php-{version}-{sapi}-{channel}
php-{version}-{sapi}-{channel}-{platform}-{arch}.tar.gz
```

For example:

```text
php-8.5.9-cli-common
php-8.5.9-cli-common-linux-x86_64.tar.gz
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
`php:cli` release from the `common` channel, and executes PHP and Composer.

## License

[MIT](LICENSE)
