# NOTE: Open bugs in Pydantic like https://github.com/pydantic/pydantic/issues/8984 prevent the full switch to the type
# keyword introduced in Python 3.12.
from collections.abc import Set
from typing import (
    Annotated,
    Final,
    Literal,
    get_args,
)

from pydantic import Field, TypeAdapter

from cuda_redist.extra_pydantic import PydanticTypeAdapter

IgnoredRedistSystem = Literal["linux-ppc64le", "windows-x86_64"]
IgnoredRedistSystems: Final[Set[IgnoredRedistSystem]] = set(get_args(IgnoredRedistSystem))

RedistSystem = Literal[
    "linux-aarch64",
    "linux-all",  # Taken to mean all other linux systems
    "linux-sbsa",
    "linux-x86_64",
    "source",  # Source-agnostic
]
RedistSystems: Final[Set[RedistSystem]] = set(get_args(RedistSystem))

RedistName = Literal[
    "cublasmp",
    "cuda",
    "cudnn",
    "cudss",
    "cuquantum",
    "cusolvermp",
    "cusparselt",
    "cutensor",
    "nppplus",
    # NOTE: Some of the earlier manifests don't follow our scheme.
    # "nvidia-driver"
    "nvjpeg2000",
    "nvpl",
    "nvtiff",
    # TensorRT is a special case.
    "tensorrt",
]
RedistNames: Final[Set[RedistName]] = set(get_args(RedistName))

RedistUrlPrefix: Final[str] = "https://developer.download.nvidia.com/compute"

Md5 = Annotated[
    str,
    Field(
        description="An MD5 hash.",
        examples=["0123456789abcdef0123456789abcdef"],
        pattern=r"[0-9a-f]{32}",
    ),
]
Md5TA: Final[TypeAdapter[Md5]] = PydanticTypeAdapter(Md5)

Sha256 = Annotated[
    str,
    Field(
        description="A SHA256 hash.",
        examples=["0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"],
        pattern=r"[0-9a-f]{64}",
    ),
]
Sha256TA: Final[TypeAdapter[Sha256]] = PydanticTypeAdapter(Sha256)

SriHash = Annotated[
    str,
    Field(
        description="An SRI hash.",
        examples=["sha256-LxcXgwe1OCRfwDsEsNLIkeNsOcx3KuF5Sj+g2dY6WD0="],
        pattern=r"(?<algorithm>md5|sha1|sha256|sha512)-[A-Za-z0-9+/]+={0,2}",
    ),
]
SriHashTA: Final[TypeAdapter[SriHash]] = PydanticTypeAdapter(SriHash)

CudaVariant = Annotated[
    str,
    Field(
        description="A CUDA variant (only including major versions).",
        examples=["cuda10", "cuda11", "cuda12"],
        pattern=r"cuda\d+",
    ),
]
CudaVariantTA: Final[TypeAdapter[CudaVariant]] = PydanticTypeAdapter(CudaVariant)

PackageName = Annotated[
    str,
    Field(
        description="The name of a package.",
        examples=["cublasmp", "cuda", "cudnn", "cudss", "cuquantum", "cusolvermp", "cusparselt", "cutensor"],
        pattern=r"[_a-z]+",
    ),
]
PackageNameTA: Final[TypeAdapter[PackageName]] = PydanticTypeAdapter(PackageName)

Date = Annotated[
    str,
    Field(
        description="A date in the format YYYY-MM-DD.",
        examples=["2022-01-01", "2022-12-31"],
        pattern=r"\d{4}-\d{2}-\d{2}",
    ),
]
DateTA: Final[TypeAdapter[Date]] = PydanticTypeAdapter(Date)

MajorVersion = Annotated[
    str,
    Field(
        description="A major version number.",
        examples=["10", "11", "12"],
        pattern=r"\d+",
    ),
]
MajorVersionTA: Final[TypeAdapter[MajorVersion]] = PydanticTypeAdapter(MajorVersion)

Version = Annotated[
    str,
    Field(
        description="A version number with one-to-four components.",
        examples=["11.0.3", "450.00.1", "22.01.03"],
        pattern=r"\d+(?:\.\d+){0,3}",
    ),
]
VersionTA: Final[TypeAdapter[Version]] = PydanticTypeAdapter(Version)

LibSoName = Annotated[
    str,
    Field(
        description="The name of a shared object file.",
        examples=["libcuda.so", "libcuda.so.1", "libcuda.so.1.2.3"],
        pattern=r"\.so(?:\.\d+)*$",
    ),
]
LibSoNameTA: TypeAdapter[LibSoName] = PydanticTypeAdapter(LibSoName)

CudaRealArch = Annotated[
    str,
    Field(
        description="""A "real" CUDA architecture.""",
        examples=["sm_35", "sm_50", "sm_60", "sm_70", "sm_75", "sm_80", "sm_86", "sm_90a"],
        pattern=r"^sm_\d+[a-z]?$",
    ),
]
CudaRealArchTA: TypeAdapter[CudaRealArch] = PydanticTypeAdapter(CudaRealArch)
