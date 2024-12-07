from argparse import ArgumentParser, Namespace
from collections.abc import Mapping, Sequence
from logging import Logger
from pathlib import Path
from typing import Final

from cuda_redist.extra_types import RedistName, RedistNames, Version, VersionTA
from cuda_redist.logger import get_logger
from cuda_redist.nvidia_index import NvidiaManifest

LOGGER: Final[Logger] = get_logger(__name__)


def setup_argparse() -> ArgumentParser:
    parser = ArgumentParser(description="Updates NVIDIA manifests stored on disk")
    _ = parser.add_argument(
        "--redist-name",
        type=str,
        choices=sorted(RedistNames | {"all"}),
        help="The name of the redistributable",
        required=True,
    )
    _ = parser.add_argument(
        "--version",
        type=str,
        help="The version of the redistributable, 'latest', or 'all'",
        required=True,
    )
    return parser


def get_redist_names(maybe_redist_name: str) -> Sequence[RedistName]:
    redist_names: Sequence[RedistName]
    if maybe_redist_name in RedistNames:
        redist_names = [maybe_redist_name]  # type: ignore
    elif maybe_redist_name == "all":
        redist_names = sorted(RedistNames)
    else:
        raise ValueError(f"Invalid redistributable name: {maybe_redist_name}")

    LOGGER.info("Using redistributable(s) %s", redist_names)
    return redist_names


def get_version_map(
    redist_names: Sequence[RedistName],
    maybe_version: str,
    maybe_tensorrt_manifest_dir: Path | None,
) -> Mapping[RedistName, Sequence[Version]]:
    if maybe_version == "all":
        LOGGER.info("Using all versions")
        return {
            redist_name: NvidiaManifest.get_versions(redist_name, maybe_tensorrt_manifest_dir)
            for redist_name in redist_names
        }
    elif maybe_version == "latest":
        LOGGER.info("Using latest version")
        return {
            redist_name: [NvidiaManifest.get_versions(redist_name, maybe_tensorrt_manifest_dir)[-1]]
            for redist_name in redist_names
        }
    elif len(redist_names) == 1:
        LOGGER.info("Using provided version")
        return {redist_name: [VersionTA.validate_strings(maybe_version)] for redist_name in redist_names}
    else:
        raise ValueError("Cannot specify a version when updating multiple redistributables")


def get_output_map(version_map: Mapping[RedistName, Sequence[Version]]) -> Mapping[tuple[RedistName, Version], Path]:
    base_path: Path = Path(".") / "nvidia-redist-json"
    output_map: Mapping[tuple[RedistName, Version], Path] = {
        (redist_name, version): base_path / redist_name / f"redistrib_{version}.json"
        for redist_name, versions in version_map.items()
        for version in versions
    }
    return output_map


def main() -> None:
    parser = setup_argparse()
    args: Namespace = parser.parse_args()
    redist_names: Sequence[RedistName] = get_redist_names(args.redist_name)
    tensorrt_manifest_dir: Path = Path(".") / "nvidia-redist-json" / "tensorrt"
    version_map: Mapping[RedistName, Sequence[Version]] = get_version_map(
        redist_names,
        args.version,
        tensorrt_manifest_dir,
    )
    output_map: Mapping[tuple[RedistName, Version], Path] = get_output_map(version_map)
    for (redist_name, version), path in output_map.items():
        nvidia_manifest_bytes = NvidiaManifest.get_from_web_as_bytes(redist_name, version, tensorrt_manifest_dir)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(nvidia_manifest_bytes)
