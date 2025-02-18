# NOTE: Open bugs in Pydantic like https://github.com/pydantic/pydantic/issues/8984 prevent the full switch to the type
# keyword introduced in Python 3.12.
import base64
from collections.abc import Iterable
from hashlib import sha256
from pathlib import Path

from cuda_redist.extra_types import (
    CudaVariant,
    PackageName,
    RedistName,
    RedistSystem,
    RedistUrlPrefix,
    Sha256,
    SriHash,
    SriHashTA,
    Version,
)


def sha256_bytes_to_sri_hash(sha256_bytes: bytes) -> SriHash:
    base64_hash = base64.b64encode(sha256_bytes).decode("utf-8")
    sri_hash = f"sha256-{base64_hash}"
    return SriHashTA.validate_strings(sri_hash)


def sha256_to_sri_hash(sha256: Sha256) -> SriHash:
    """
    Convert a Base16 SHA-256 hash to a Subresource Integrity (SRI) hash.
    """
    return sha256_bytes_to_sri_hash(bytes.fromhex(sha256))


def mk_sri_hash(bs: bytes) -> SriHash:
    """
    Compute a Subresource Integrity (SRI) hash from a byte string.
    """
    return sha256_bytes_to_sri_hash(sha256(bs).digest())


def mk_relative_path(
    package_name: PackageName,
    system: RedistSystem,
    version: Version,
    cuda_variant: CudaVariant | None,
) -> Path:
    return (
        Path(package_name)
        / system
        / "-".join([
            package_name,
            system,
            (version + (f"_{cuda_variant}" if cuda_variant is not None else "")),
            "archive.tar.xz",
        ])
    )


def mk_redist_url(
    redist_name: RedistName,
    relative_path: Path,
) -> str:
    match redist_name:
        case "tensorrt":
            return f"{RedistUrlPrefix}/machine-learning/{relative_path}"
        case _:
            return f"{RedistUrlPrefix}/{redist_name}/redist/{relative_path}"


def newest_version(versions: Iterable[Version]) -> Version:
    return max(versions, key=lambda version: tuple(map(int, version.split("."))))
