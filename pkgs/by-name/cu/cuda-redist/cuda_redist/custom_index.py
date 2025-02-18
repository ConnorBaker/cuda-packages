# NOTE: Open bugs in Pydantic like https://github.com/pydantic/pydantic/issues/8984 prevent the full switch to the type
# keyword introduced in Python 3.12.
import json
import time
from collections.abc import Mapping
from logging import Logger
from pathlib import Path
from typing import (
    Final,
    Self,
    TypeAlias,
)

from cuda_redist.extra_pydantic import PydanticMapping, PydanticObject
from cuda_redist.extra_types import (
    CudaVariant,
    PackageName,
    RedistName,
    RedistSystem,
    Sha256,
    SriHash,
    Version,
)
from cuda_redist.feature_detector.cuda_versions_in_lib import FeatureCudaVersionsInLib
from cuda_redist.feature_detector.outputs import FeatureOutputs
from cuda_redist.logger import get_logger
from cuda_redist.nix_store_entry import NixStoreEntry
from cuda_redist.nvidia_index import NvidiaIndex, NvidiaManifest, NvidiaPackage, NvidiaReleaseV2, NvidiaReleaseV3
from cuda_redist.utilities import mk_redist_url, mk_relative_path

LOGGER: Final[Logger] = get_logger(__name__)


class CustomPackageFeatures(PydanticObject):
    """
    Features of a package in the manifest.
    """

    # cuda_architectures: FeatureCudaArchitectures | None
    cuda_versions_in_lib: FeatureCudaVersionsInLib | None
    outputs: FeatureOutputs

    @classmethod
    def mk(cls: type[Self], store_path: Path) -> Self:
        LOGGER.info("Finding features for %s...", store_path)
        start_time = time.time()

        cuda_versions_in_lib = FeatureCudaVersionsInLib.of(store_path)
        outputs = FeatureOutputs.of(store_path)

        end_time = time.time()
        LOGGER.info("Found features for %s in %d seconds.", store_path, end_time - start_time)

        # Replace empty sequences with None.
        return cls.model_validate({
            "cudaVersionsInLib": cuda_versions_in_lib or None,
            "outputs": outputs,
        })


class CustomPackageInfo(PydanticObject):
    """
    A package in the manifest, with a hash and a relative path.

    The relative path is None when it can be reconstructed from information in the index.

    A case where the relative path is non-None: TensorRT, which does not follow the usual naming convention.
    """

    recursive_hash: SriHash
    features: CustomPackageFeatures
    relative_path: Path | None = None

    @classmethod
    def mk(
        cls: type[Self],
        redist_name: RedistName,
        actual_relative_path: Path,
        sha256: Sha256,
        expected_relative_path: Path,
    ) -> Self:
        url: str = mk_redist_url(redist_name, actual_relative_path)
        unpacked_store_entry = NixStoreEntry.unpacked_from_url(url, sha256)
        recursive_hash = unpacked_store_entry.hash

        features = CustomPackageFeatures.mk(unpacked_store_entry.store_path)

        # Verify that we can compute the correct relative path before throwing it away.
        blob = {
            "recursive_hash": recursive_hash,
            "features": features,
            "relative_path": None,
        }
        if actual_relative_path != expected_relative_path:
            # TensorRT will fail this check because it doesn't follow the usual naming convention.
            if redist_name != "tensorrt":
                LOGGER.info(
                    "Expected relative path to be %s, got %s",
                    expected_relative_path,
                    actual_relative_path,
                )
            return cls.model_validate(blob | {"relative_path": actual_relative_path})
        else:
            return cls.model_validate(blob)


class CustomReleaseInfo(PydanticObject):
    """
    Top-level values in the manifest from keys not prefixed with release_, augmented with the package_name.
    """

    license_path: Path | None = None
    license: str | None = None
    name: str | None = None
    version: Version

    @classmethod
    def mk(cls: type[Self], nvidia_release: NvidiaReleaseV2 | NvidiaReleaseV3) -> Self:
        """
        Creates an instance of ReleaseInfo from the provided manifest dictionary, removing the fields
        used to create the instance from the dictionary.
        """
        return cls.model_validate({
            "license_path": nvidia_release.license_path,
            "license": nvidia_release.license,
            "name": nvidia_release.name,
            "version": nvidia_release.version,
        })


class CustomPackageVariants(PydanticMapping[CudaVariant | None, CustomPackageInfo]):
    @classmethod
    def mk(
        cls: type[Self],
        redist_name: RedistName,
        package_name: PackageName,
        release_info: CustomReleaseInfo,
        system: RedistSystem,
        package_or_cuda_variants_to_packages: NvidiaPackage | Mapping[CudaVariant, NvidiaPackage],
    ) -> Self:
        """
        Creates an instance of PackageInfo from the provided manifest dictionary, removing the fields
        used to create the instance from the dictionary.
        NOTE: Because the keys may be prefixed with "cuda", indicating multiple packages, we return a sequence of
        PackageInfo instances.
        """
        if isinstance(package_or_cuda_variants_to_packages, NvidiaPackage):
            obj = {None: package_or_cuda_variants_to_packages}
        else:
            obj = package_or_cuda_variants_to_packages

        infos: dict[CudaVariant | None, CustomPackageInfo] = {}
        for cuda_variant_name, nvidia_package in obj.items():
            package_info: CustomPackageInfo = CustomPackageInfo.mk(
                redist_name,
                nvidia_package.relative_path,
                nvidia_package.sha256,
                expected_relative_path=mk_relative_path(
                    package_name, system, release_info.version, cuda_variant_name
                ),
            )
            infos[cuda_variant_name] = package_info
        return cls.model_validate(infos)


CustomPackages: TypeAlias = PydanticMapping[RedistSystem, CustomPackageVariants]


class CustomRelease(PydanticObject):
    release_info: CustomReleaseInfo
    packages: CustomPackages

    @classmethod
    def mk(
        cls: type[Self],
        redist_name: RedistName,
        package_name: PackageName,
        nvidia_release: NvidiaReleaseV2 | NvidiaReleaseV3,
    ) -> Self:
        release_info = CustomReleaseInfo.mk(nvidia_release)

        packages: dict[RedistSystem, CustomPackageVariants] = {
            system: CustomPackageVariants.mk(
                redist_name,
                package_name,
                release_info,
                system,
                package_or_cuda_variants_to_packages,
            )
            for system, package_or_cuda_variants_to_packages in nvidia_release.packages().items()
        }

        return cls.model_validate({"release_info": release_info, "packages": packages})


class CustomManifest(PydanticMapping[PackageName, CustomRelease]):
    @classmethod
    def mk(
        cls: type[Self],
        redist_name: RedistName,
        nvidia_manifest: NvidiaManifest,
    ) -> Self:
        # TODO: How do we effectively handle tree-structured parallelism?
        releases: dict[str, CustomRelease] = {
            package_name: release
            for package_name, nvidia_release in nvidia_manifest.releases().items()
            # Don't include releases for packages that have no packages for the systems we care about.
            if len((release := CustomRelease.mk(redist_name, package_name, nvidia_release)).packages) != 0
        }

        return cls.model_validate(releases)


CustomVersionedManifests: TypeAlias = PydanticMapping[Version, CustomManifest]


class CustomIndex(PydanticMapping[RedistName, CustomVersionedManifests]):
    @classmethod
    def mk(cls: type[Self], nvidia_index: NvidiaIndex) -> Self:
        return cls.model_validate({
            redist_name: {
                version: CustomManifest.mk(redist_name, nvidia_manifest)
                for version, nvidia_manifest in versioned_nvidia_manifests.items()
            }
            for redist_name, versioned_nvidia_manifests in nvidia_index.items()
        })

    def save_to_disk(self: Self) -> None:
        for redist_name, versioned_custom_manifests in self.model_dump(
            by_alias=True,
            exclude_none=True,
            exclude_unset=True,
            mode="json",
        ).items():
            for version, custom_manifest in versioned_custom_manifests.items():
                output_path: Path = Path(".") / "modules" / "redists" / redist_name / "manifests" / f"{version}.json"
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with output_path.open(mode="w", encoding="utf-8") as file:
                    json.dump(
                        custom_manifest,
                        file,
                        indent=2,
                        sort_keys=True,
                    )
