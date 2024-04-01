import logging

from mirror_builder import external_commands

logger = logging.getLogger(__name__)


def build_wheel(ctx, req_type, req, resolved_name, why, sdist_root_dir):
    # flit_core is a basic build system dependency for several
    # packages. It is capable of building its own wheels, so we use the
    # bootstrapping instructions to do that and put the wheel in the
    # local server directory for reuse when building other packages via
    # 'pip wheel'.
    #
    # https://flit.pypa.io/en/stable/bootstrap.html
    logger.info('bootstrapping flit_core wheel in %s', sdist_root_dir)
    external_commands.run(
        ['python3', '-m', 'flit_core.wheel'],
        cwd=sdist_root_dir,
    )
    return (sdist_root_dir / 'dist').glob('*.whl')
