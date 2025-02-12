from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Final

from pydantic import TypeAdapter

from cuda_redist.extra_pydantic import PydanticTypeAdapter
from cuda_redist.extra_types import CudaRealArch
from cuda_redist.feature_detector.detectors.cuda_architectures import CudaArchitecturesDetector

FeatureCudaArchitectures = Sequence[CudaRealArch] | Mapping[str, Sequence[CudaRealArch]]
FeatureCudaArchitecturesTA: Final[TypeAdapter[FeatureCudaArchitectures]] = PydanticTypeAdapter(FeatureCudaArchitectures)


def mkFeatureCudaArchitectures(store_path: Path) -> FeatureCudaArchitectures:
    ret: Sequence[CudaRealArch] | Mapping[str, Sequence[CudaRealArch]] | None = CudaArchitecturesDetector().find(
        store_path
    )
    return FeatureCudaArchitecturesTA.validate_python(ret or [])
