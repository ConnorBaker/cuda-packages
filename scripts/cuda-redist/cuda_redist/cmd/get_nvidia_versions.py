from argparse import ArgumentParser, Namespace
from logging import Logger
from pathlib import Path
from typing import Final

from cuda_redist.extra_types import RedistName, RedistNames
from cuda_redist.logger import get_logger
from cuda_redist.nvidia_index import NvidiaManifest

LOGGER: Final[Logger] = get_logger(__name__)


def setup_argparse() -> ArgumentParser:
    parser = ArgumentParser(description="Gets the versions of manifests available for a redistributable")
    _ = parser.add_argument(
        "--redist-name",
        type=str,
        choices=RedistNames,
        help="The name of the redistributable",
        required=True,
    )
    return parser


def main() -> None:
    parser = setup_argparse()
    args: Namespace = parser.parse_args()
    redist_name: RedistName = args.redist_name
    tensorrt_manifest_dir: Path = Path(".") / "nvidia-redist-json" / "tensorrt"
    for version in NvidiaManifest.get_versions(redist_name, tensorrt_manifest_dir):
        print(version)
