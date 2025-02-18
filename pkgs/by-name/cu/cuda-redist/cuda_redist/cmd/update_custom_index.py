from argparse import ArgumentParser, Namespace
from collections.abc import Sequence
from logging import Logger
from pathlib import Path
from typing import Final

from cuda_redist.custom_index import CustomIndex
from cuda_redist.extra_types import RedistName, RedistNames
from cuda_redist.logger import get_logger
from cuda_redist.nvidia_index import NvidiaIndex

LOGGER: Final[Logger] = get_logger(__name__)


def setup_argparse() -> ArgumentParser:
    parser = ArgumentParser(description="Updates custom manifests stored on disk")
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


def main() -> None:
    parser = setup_argparse()
    args: Namespace = parser.parse_args()
    redist_names: Sequence[RedistName] = get_redist_names(args.redist_name)
    nvidia_index: NvidiaIndex = NvidiaIndex.get_from_disk(Path(".") / "nvidia-redist-json", redist_names, args.version)
    custom_index: CustomIndex = CustomIndex.mk(nvidia_index)
    custom_index.save_to_disk()
