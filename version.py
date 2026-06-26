"""Version metadata for the Lyndrix Android TWA. Must match the git tag (CI guards)."""

__version__ = "0.1.0"
__version_info__ = (0, 1, 0)


def get_version() -> str:
    return __version__
