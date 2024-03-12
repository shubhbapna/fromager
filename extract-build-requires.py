import argparse
import sys
import toml
import pyproject_hooks

# Extract build requirements from a pyproject.toml
#
# The --backend option is used to extract requirements using the
# build backend get_requires_for_build_wheel hook (PEP 517)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", action=argparse.BooleanOptionalAction)
    args = parser.parse_args()

    pyproject_toml = toml.loads(sys.stdin.read())

    if not args.backend:
        requires = pyproject_toml.get('build-system', {}).get('requires', [])
    else:
        hook_caller = pyproject_hooks.BuildBackendHookCaller(
            source_dir=".",
            build_backend=pyproject_toml.get('build-system', {}).get('build-backend', ''),
            backend_path=pyproject_toml.get('build-system', {}).get('backend-path', None),
            runner=pyproject_hooks.quiet_subprocess_runner)
        requires = hook_caller.get_requires_for_build_wheel()

    for req in requires:
        print(f"{req}")