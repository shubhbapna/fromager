from packaging.requirements import Requirement
from packaging.utils import canonicalize_name
from packaging.version import Version

from fromager import bootstrapper
from fromager.context import WorkContext
from fromager.dependency_graph import DependencyGraph
from fromager.requirements_file import RequirementType

old_graph = DependencyGraph()

old_graph.add_dependency(
    parent_name=None,
    parent_version=None,
    req_type=RequirementType.TOP_LEVEL,
    req=Requirement("foo"),
    req_version=Version("1.0.0"),
)

old_graph.add_dependency(
    parent_name=canonicalize_name("foo"),
    parent_version=Version("1.0.0"),
    req_type=RequirementType.INSTALL,
    req=Requirement("pbr>=5"),
    req_version=Version("7"),
)

old_graph.add_dependency(
    parent_name=None,
    parent_version=None,
    req_type=RequirementType.TOP_LEVEL,
    req=Requirement("bar"),
    req_version=Version("1.0.0"),
)

old_graph.add_dependency(
    parent_name=canonicalize_name("bar"),
    parent_version=Version("1.0.0"),
    req_type=RequirementType.INSTALL,
    req=Requirement("pbr>=5,<7"),
    req_version=Version("6"),
)

old_graph.add_dependency(
    parent_name=None,
    parent_version=None,
    req_type=RequirementType.TOP_LEVEL,
    req=Requirement("blah"),
    req_version=Version("1.0.0"),
)

old_graph.add_dependency(
    parent_name=canonicalize_name("blah"),
    parent_version=Version("1.0.0"),
    req_type=RequirementType.INSTALL,
    req=Requirement("pbr==5"),
    req_version=Version("5"),
)


def test_resolve_from_graph_no_changes(tmp_context: WorkContext):
    bt = bootstrapper.Bootstrapper(tmp_context, None, old_graph)
    bt.why = [(RequirementType.TOP_LEVEL, Requirement("foo"), Version("1.0.0"))]

    # resolving new dependency that doesn't exist in graph
    assert (
        bt._resolve_from_graph(
            req_type=RequirementType.INSTALL,
            req=Requirement("xyz"),
            pre_built=False,
        )
        is None
    )

    # resolving pbr dependency of foo
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr>=5"),
        pre_built=False,
    ) == ("", Version("7"))

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("bar"), Version("1.0.0"))]
    # resolving pbr dependency of bar
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr>=5,<7"),
        pre_built=False,
    ) == ("", Version("6"))

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("blah"), Version("1.0.0"))]
    # resolving pbr dependency of blah
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr==5"),
        pre_built=False,
    ) == ("", Version("5"))


def test_resolve_from_graph_install_dep_upgrade(tmp_context: WorkContext):
    bt = bootstrapper.Bootstrapper(tmp_context, None, old_graph)

    # simulating new bootstrap with a toplevel requirement of pbr==8
    tmp_context.dependency_graph.add_dependency(
        parent_name=None,
        parent_version=None,
        req_type=RequirementType.TOP_LEVEL,
        req=Requirement("pbr==8"),
        req_version=Version("8"),
    )

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("foo"), Version("1.0.0"))]
    # resolving pbr dependency of foo
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr>=5"),
        pre_built=False,
    ) == ("", Version("8"))

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("bar"), Version("1.0.0"))]
    # resolving pbr dependency of bar
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr>=5,<7"),
        pre_built=False,
    ) == ("", Version("6"))

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("blah"), Version("1.0.0"))]
    # resolving pbr dependency of blah
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr==5"),
        pre_built=False,
    ) == ("", Version("5"))


def test_resolve_from_graph_install_dep_downgrade(tmp_context: WorkContext):
    bt = bootstrapper.Bootstrapper(tmp_context, None, old_graph)

    # simulating new bootstrap with a toplevel requirement of pbr<=6
    tmp_context.dependency_graph.add_dependency(
        parent_name=None,
        parent_version=None,
        req_type=RequirementType.TOP_LEVEL,
        req=Requirement("pbr<=6"),
        req_version=Version("6"),
    )

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("foo"), Version("1.0.0"))]
    # resolving pbr dependency of foo
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr>=5"),
        pre_built=False,
    ) == ("", Version("6"))

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("bar"), Version("1.0.0"))]
    # resolving pbr dependency of bar
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr>=5,<7"),
        pre_built=False,
    ) == ("", Version("6"))

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("blah"), Version("1.0.0"))]
    # resolving pbr dependency of blah
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr==5"),
        pre_built=False,
    ) == ("", Version("5"))


def test_resolve_from_graph_toplevel_dep(tmp_context: WorkContext):
    bt = bootstrapper.Bootstrapper(tmp_context, None, old_graph)

    # simulating new bootstrap with a toplevel requirement for foo
    tmp_context.dependency_graph.add_dependency(
        parent_name=None,
        parent_version=None,
        req_type=RequirementType.TOP_LEVEL,
        req=Requirement("foo==2"),
        req_version=Version("2"),
    )

    # simulating new bootstrap with a toplevel requirement of bar (no change)
    tmp_context.dependency_graph.add_dependency(
        parent_name=None,
        parent_version=None,
        req_type=RequirementType.TOP_LEVEL,
        req=Requirement("bar"),
        req_version=Version("1.0.0"),
    )

    bt.why = []
    # resolving foo
    assert bt._resolve_from_graph(
        req_type=RequirementType.TOP_LEVEL,
        req=Requirement("foo==2"),
        pre_built=False,
    ) == ("", Version("2"))

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("foo"), Version("2"))]
    # resolving pbr dependency of foo even if foo version changed
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr>=5"),
        pre_built=False,
    ) == ("", Version("7"))

    bt.why = []
    # resolving bar
    assert bt._resolve_from_graph(
        req_type=RequirementType.TOP_LEVEL,
        req=Requirement("bar"),
        pre_built=False,
    ) == ("", Version("1.0.0"))

    bt.why = [(RequirementType.TOP_LEVEL, Requirement("bar"), Version("1.0.0"))]
    # resolving pbr dependency of bar
    assert bt._resolve_from_graph(
        req_type=RequirementType.INSTALL,
        req=Requirement("pbr>=5,<7"),
        pre_built=False,
    ) == ("", Version("6"))
