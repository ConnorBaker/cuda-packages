import json
import subprocess
import time
from logging import Logger
from pathlib import Path
from typing import Final, Self

from pydantic.alias_generators import to_camel

from cuda_redist.extra_pydantic import PydanticObject
from cuda_redist.extra_types import Sha256
from cuda_redist.logger import get_logger

LOGGER: Final[Logger] = get_logger(__name__)


class NixStoreEntry(PydanticObject, extra="allow", alias_generator=to_camel):
    hash: str
    store_path: Path

    @classmethod
    def unpacked_from_url(cls, url: str, sha256: Sha256) -> Self:
        """
        Adds a tarball to the Nix store and unpacks it, returning the recursive hash and unpacked store path.
        """
        # Fetch and unpack the tarball
        LOGGER.info("Adding %s to the Nix store and unpacking...", url)
        start_time = time.time()
        name = f"{url.split('/')[-1]}-unpacked"
        result = subprocess.run(
            [
                "nix",
                "build",
                "--builders",
                "''",
                "--impure",
                "--no-link",
                "--json",
                "--expr",
                f"""
                let
                    nixpkgs = builtins.getFlake "github:NixOS/nixpkgs/refs/tags/25.05-pre";
                    pkgs = import nixpkgs.outPath {{ system = builtins.currentSystem; }};
                in
                pkgs.srcOnly {{
                    __structuredAttrs = true;
                    strictDeps = true;
                    stdenv = pkgs.stdenvNoCC;
                    name = "{name}";
                    src = pkgs.fetchurl {{
                        url = "{url}";
                        sha256 = "{sha256}";
                    }};
                }}
                """,
            ],
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            LOGGER.error("nix build exited with code %d", result.returncode)
            LOGGER.error("nix build stdout: %s", result.stdout.decode())
            LOGGER.error("nix build stderr: %s", result.stderr.decode())
            raise RuntimeError()
        result_blob = json.loads(result.stdout)
        store_path = Path(result_blob[0]["outputs"]["out"])

        # Get the hash of the unpacked store path
        result = subprocess.run(
            [
                "nix",
                "path-info",
                "--json",
                store_path.as_posix(),
            ],
            capture_output=True,
            check=True,
        )
        result_blob = json.loads(result.stdout)
        nar_hash = result_blob[store_path.as_posix()]["narHash"]

        end_time = time.time()
        LOGGER.info("Added %s to the Nix store and unpacked in %d seconds.", url, end_time - start_time)

        return cls.model_validate({
            "hash": nar_hash,
            "storePath": store_path,
        })

    def delete(self) -> None:
        """
        Delete paths from the Nix store.
        """
        str_path: str = self.store_path.as_posix()
        LOGGER.info("Deleting %s from the Nix store...", str_path)
        start_time = time.time()
        subprocess.run(
            ["nix", "store", "delete", str_path],
            capture_output=True,
            check=True,
        )
        end_time = time.time()
        LOGGER.info("Deleted %s from the Nix store in %d seconds.", str_path, end_time - start_time)
