# NOTE: Open bugs in Pydantic like https://github.com/pydantic/pydantic/issues/8984 prevent the full switch to the type
# keyword introduced in Python 3.12.
import re
from collections import defaultdict
from collections.abc import Mapping, Sequence
from logging import Logger
from pathlib import Path
from typing import Annotated, Final, Literal, Self, TypeAlias, TypeVar
from urllib import request

from pydantic import Field, field_validator, model_validator
from typing_extensions import override

from cuda_redist.extra_pydantic import ModelConfigAllowExtra, PydanticMapping, PydanticObject
from cuda_redist.extra_types import (
    CudaVariant,
    Date,
    IgnoredRedistSystems,
    MajorVersion,
    Md5,
    PackageName,
    PackageNameTA,
    RedistName,
    RedistNames,
    RedistSystem,
    RedistSystems,
    RedistUrlPrefix,
    Sha256,
    Version,
    VersionTA,
)
from cuda_redist.logger import get_logger
from cuda_redist.utilities import newest_version

LOGGER: Final[Logger] = get_logger(__name__)


NvidiaReleaseCommonTy = TypeVar("NvidiaReleaseCommonTy", bound="NvidiaReleaseCommon")


def _check_extra_keys_are_systems(self: NvidiaReleaseCommonTy) -> NvidiaReleaseCommonTy:
    """
    Ensure that all redistributable systems are present as keys. Additionally removes ignored systems from the
    extra fields.

    This is to avoid the scenario wherein the systems are updated but this class is not.
    """
    if not self.__pydantic_extra__:
        LOGGER.info("No redistributable systems found for %s version %s", self.name, self.version)
        return self

    # Remove ignored systems
    for system in IgnoredRedistSystems & self.__pydantic_extra__.keys():
        del self.__pydantic_extra__[system]  # pyright: ignore[reportArgumentType]

    # Check for keys which are not systems
    if unexpected_keys := self.__pydantic_extra__.keys() - RedistSystems:
        unexpected_keys_str = ", ".join(sorted(unexpected_keys))
        raise ValueError(f"Unexpected system key(s) encountered: {unexpected_keys_str}")

    return self


class NvidiaPackage(PydanticObject):
    relative_path: Annotated[Path, Field(description="Relative path to the package from the index URL.")]
    sha256: Annotated[Sha256, Field(description="SHA256 hash of the package.")]
    md5: Annotated[Md5, Field(description="MD5 hash of the package.")]
    size: Annotated[
        str,
        Field(description="Size of the package in bytes, as a string.", pattern=r"\d+"),
    ]


class NvidiaReleaseCommon(PydanticObject):
    name: Annotated[str, Field(description="Full name and description of the release.")]
    license: Annotated[str, Field(description="License under which the release is distributed.")]
    license_path: Annotated[
        Path | None,
        Field(description="Relative path to the license file.", default=None),
    ]
    version: Annotated[Version, Field(description="Version of the release.")]

    def packages(self) -> Mapping[RedistSystem, NvidiaPackage | Mapping[CudaVariant, NvidiaPackage]]:
        # Only implemented in subclasses
        raise NotImplementedError()


# Does not have or use `cuda_variant` field
# Does not have a `source` system
# Does not have a `linux-all` system
class NvidiaReleaseV2(NvidiaReleaseCommon):
    model_config = ModelConfigAllowExtra
    __pydantic_extra__: dict[  # pyright: ignore[reportIncompatibleVariableOverride]
        RedistSystem,  # NOTE: This is an invariant we must maintain
        NvidiaPackage,
    ]

    @model_validator(mode="after")
    def check_extra_keys_are_systems(self) -> Self:
        return _check_extra_keys_are_systems(self)

    @override
    def packages(self) -> Mapping[RedistSystem, NvidiaPackage]:
        return self.__pydantic_extra__


# Has `cuda_variant` field
class NvidiaReleaseV3(NvidiaReleaseCommon):
    model_config = ModelConfigAllowExtra
    __pydantic_extra__: dict[  # pyright: ignore[reportIncompatibleVariableOverride]
        RedistSystem,  # NOTE: This is an invariant we must maintain
        NvidiaPackage | Mapping[CudaVariant, NvidiaPackage],  # NOTE: Neither `source` nor `linux-all` use cuda variants
    ]

    cuda_variant: Annotated[
        Sequence[MajorVersion],
        Field(description="CUDA variants supported by the release."),
    ]

    @field_validator("cuda_variant", mode="after")
    @classmethod
    def validate_cuda_variant(cls, value: Sequence[MajorVersion]) -> Sequence[MajorVersion]:
        if value == []:
            raise ValueError("`cuda_variant` cannot be an empty list.")
        return value

    @model_validator(mode="after")
    def check_extra_keys_are_systems(self) -> Self:
        return _check_extra_keys_are_systems(self)

    @model_validator(mode="after")
    def check_exclusive_systems_are_exclusive(self) -> Self:
        """
        Ensure that the `linux-all` and `source` systems are exclusive with all the others.
        """
        for exclusive_system in ["linux-all", "source"]:
            if exclusive_system in self.__pydantic_extra__:
                if len(self.__pydantic_extra__) > 1:
                    raise ValueError(f"The `{exclusive_system}` system is exclusive with all the others.")

                if self.cuda_variant != []:
                    raise ValueError(f"The `{exclusive_system}` system requires `cuda_variant` be empty.")

        return self

    @model_validator(mode="after")
    def check_extra_fields_have_cuda_variant_keys(self) -> Self:
        """
        Ensure the values of the extra fields are objects keyed by CUDA variant.
        """
        allowed_cuda_variants = {f"cuda{major_version}" for major_version in self.cuda_variant}
        for system, variants in self.__pydantic_extra__.items():
            if system in {"linux-all", "source"} and not isinstance(variants, NvidiaPackage):
                raise ValueError(f"System `{system}` must have a single package.")
            elif not isinstance(variants, Mapping):
                raise ValueError(f"System `{system}` does not have a mapping of CUDA variants.")

            # Check for keys which are not CUDA variants
            if unexpected_keys := variants.keys() - allowed_cuda_variants:
                unexpected_keys_str = ", ".join(sorted(unexpected_keys))
                raise ValueError(
                    f"Unexpected CUDA variant(s) encountered for system {system}: {unexpected_keys_str}"
                )

        return self

    @override
    def packages(
        self,
    ) -> Mapping[RedistSystem, NvidiaPackage | Mapping[CudaVariant, NvidiaPackage]]:
        return self.__pydantic_extra__


# A manifest contains many release objects.
class NvidiaManifest(PydanticObject):
    model_config = ModelConfigAllowExtra
    __pydantic_extra__: dict[  # pyright: ignore[reportIncompatibleVariableOverride]
        PackageName,  # NOTE: This is an invariant we must maintain
        NvidiaReleaseV3 | NvidiaReleaseV2,
    ]

    release_date: Annotated[Date, Field(description="Date of the manifest.")]
    release_label: Annotated[Version | None, Field(description="Label of the manifest.", default=None)]
    release_product: Annotated[
        RedistName | str | None,  # NOTE: This should be RedistName, but cublasmp 0.1.0 release does not conform
        Field(
            description="Product name of the manifest.",
            default=None,
        ),
    ]

    @model_validator(mode="after")
    def check_extra_keys_are_package_names(self) -> Self:
        """
        Ensure that all keys in `__pydantic_extra__` are package names.
        """
        if not self.__pydantic_extra__:
            raise ValueError("No redistributable packages found.")

        # Check for keys which are not package names
        for potential_package_name in self.__pydantic_extra__.keys():
            _ = PackageNameTA.validate_strings(potential_package_name)

        return self

    def releases(self) -> Mapping[PackageName, NvidiaReleaseV2 | NvidiaReleaseV3]:
        return self.__pydantic_extra__

    @staticmethod
    def is_ignored(redist_name: RedistName, version: Version) -> str | None:
        """Return a reason to ignore the manifest, or None if it should not be ignored."""
        match redist_name:
            # These CUDA manifests are old enough that they don't conform to the same structure as the newer ones.
            case "cuda" if tuple(map(int, version.split("."))) < (11, 4, 2):
                return "versions before 11.4.2 do not conform to the expected structure"
            # The cuDNN manifests with four-component versions don't have a cuda_variant field.
            # The three-component versions are fine.
            case "cudnn" if len(version.split(".")) == 4:  # noqa: PLR2004
                return "uses lib directory structure instead of cuda variant"
            case _:
                return None

    # TODO: Version policy should be handled by Nix expressions in deciding which package sets to create.
    # @staticmethod
    # def get_num_version_components(redist_name: RedistName) -> int:
    #     """
    #     For CUDA, and CUDA only, we take only the latest minor version for each major version.
    #     For other packages, like cuDNN, we take the latest patch version for each minor version.
    #     An example of why we do this: between patch releases of cuDNN, NVIDIA may not offer support for all
    #     architecutres! For instance, cuDNN 8.9.5 supports Jetson, but cuDNN 8.9.6 does not.
    #     """
    #     match redist_name:
    #         case "cuda":
    #             return 2
    #         case _:
    #             return 3

    @staticmethod
    def get_versions(redist_name: RedistName, tensorrt_manifest_dir: Path | None = None) -> Sequence[Version]:
        LOGGER.info("Getting versions for %s", redist_name)
        regex_pattern = re.compile(
            r"""
            href\s*=\s*          # Match 'href', optional whitespace, '=', optional whitespace
            ['"]                 # Match opening quote (single or double)
            redistrib_           # Match 'redistrib_'
            (?P<version>[\d\.]+) # Capture the version number
            \.json               # Match '.json'
            ['"]                 # Match closing quote (single or double)
            """,
            flags=re.VERBOSE,
        )

        # Map major and minor component to the tuple of all components and the version string.
        version_dict: dict[tuple[int, ...], tuple[tuple[int, ...], Version]] = {}

        listing: str
        match redist_name:
            case "tensorrt":
                if tensorrt_manifest_dir is None:
                    raise ValueError("Must provide the path to the tensorrt manifests")
                # Fake HTML listing
                listing = "\n".join(
                    '<a href="' + redistrib_path.name + '">' + redistrib_path.name + "</a>"
                    for redistrib_path in sorted(tensorrt_manifest_dir.iterdir())
                    if redistrib_path.is_file()
                )
            case _:
                with request.urlopen(f"{RedistUrlPrefix}/{redist_name}/redist/index.html") as response:
                    listing = response.read().decode("utf-8")

        for raw_version_match in regex_pattern.finditer(listing):
            raw_version: str = raw_version_match.group("version")
            version = VersionTA.validate_strings(raw_version)

            reason = NvidiaManifest.is_ignored(redist_name, version)
            if reason:
                LOGGER.info("Ignoring manifest %s version %s: %s", redist_name, version, reason)
                continue

            # Take only the latest minor version for each major version.
            components = tuple(map(int, version.split(".")))
            existing_components, _ = version_dict.get(components, (None, None))
            if existing_components is None or components > existing_components:
                version_dict[components] = (components, version)

        return [version for _, version in version_dict.values()]

    @staticmethod
    def get_from_web_as_bytes(
        redist_name: RedistName, version: Version, tensorrt_manifest_dir: Path | None = None
    ) -> bytes:
        LOGGER.info("Getting manifest for %s %s", redist_name, version)
        match redist_name:
            case "tensorrt":
                if tensorrt_manifest_dir is None:
                    raise ValueError("Must provide the path to the tensorrt manifests")
                return (tensorrt_manifest_dir / f"redistrib_{version}.json").read_bytes()
            case _:
                return request.urlopen(f"{RedistUrlPrefix}/{redist_name}/redist/redistrib_{version}.json").read()

    @classmethod
    def get_from_web(
        cls: type[Self], redist_name: RedistName, version: Version, tensorrt_manifest_dir: Path | None = None
    ) -> Self:
        return cls.model_validate_json(cls.get_from_web_as_bytes(redist_name, version, tensorrt_manifest_dir))


NvidiaVersionedManifests: TypeAlias = PydanticMapping[Version, NvidiaManifest]


class NvidiaIndex(PydanticMapping[RedistName, NvidiaVersionedManifests]):
    @classmethod
    def get_from_disk(
        cls: type[Self],
        manifests_dir: Path,
        redist_names: Sequence[RedistName] | None = None,
        version: Literal["all", "latest"] | Version = "all",
    ) -> Self:
        """
        Read all redistributable manifests from the given directory. Directory structure should be as follows:

        ```
        manifests_dir/
        ├── cudnn/
        │   ├── redistrib_9.3.0.json
        │   ├── redistrib_9.4.0.json
        │   └── ...
        ├── cuda/
        │   ├── redistrib_12.5.1.json
        │   ├── redistrib_12.6.1.json
        │   └── ...
        ├── ...
        ```

        Only directories with valid redistributable names are considered. Only JSON files are considered in each
        directory.

        Optionally accepts `redist_names` to limit the manifest reading to a subset of redistributables. If `version` is
        "all", all versions are read. If `version` is "latest", only the latest version is read. If `version` is a
        specific version, only that version is read -- this is only valid if `redist_names` has a single element.
        """
        d: dict[RedistName, dict[Version, NvidiaManifest]] = defaultdict(dict)
        effective_redist_names = set(redist_names) if redist_names is not None else RedistNames
        for redist_name_dir in sorted(
            filter(lambda p: p.is_dir() and p.name in effective_redist_names, manifests_dir.iterdir())
        ):
            LOGGER.info("Reading directory %s", redist_name_dir)
            redist_name: RedistName = redist_name_dir.name  # type: ignore
            json_files = sorted(filter(lambda p: p.is_file() and p.suffix == ".json", redist_name_dir.iterdir()))
            if version == "all":
                pass
            elif version == "latest":
                versioned_paths = {path.stem.split("_")[1]: path for path in json_files}
                json_files = [versioned_paths[newest_version(versioned_paths.keys())]]
            elif len(effective_redist_names) == 1:
                json_files = [redist_name_dir / f"redistrib_{version}.json"]
            else:
                raise ValueError("Cannot specify a version when reading multiple redistributables")

            for redistrib_json_path in json_files:
                redistrib_version = redistrib_json_path.stem.split("_")[1]
                LOGGER.info("Reading file %s", redistrib_json_path)
                d[redist_name][redistrib_version] = NvidiaManifest.model_validate_json(redistrib_json_path.read_bytes())

        return cls.model_validate(d)
