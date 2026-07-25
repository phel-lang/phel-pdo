<?php

declare(strict_types=1);

use Phel\Config\PhelConfig;

// Required for consumers, not for this repo's own test run.
//
// Phel discovers a dependency's namespaces by reading its `phel-config.php`.
// Without this file the package installs cleanly and then `(:require phel\pdo)`
// fails with "Cannot resolve symbol 'pdo/connect'" - the library only works
// inside its own checkout, where `src/` is already the project's source dir.
//
// That was issue #1 of this repo, fixed in 0.0.5 by adding this file, and
// reintroduced in 0.1.0 by removing it as "no special config needed". The
// consumer smoke test in .github/workflows/consumer.yml exists so it cannot
// happen a third time.
return PhelConfig::forProject()
    ->withMainPhelNamespace('phel.pdo');
