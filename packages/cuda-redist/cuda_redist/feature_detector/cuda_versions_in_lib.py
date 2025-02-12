from collections.abc import Sequence
from pathlib import Path
from typing import Self

from cuda_redist.extra_pydantic import PydanticSequence
from cuda_redist.extra_types import Version
from cuda_redist.feature_detector.detectors import CudaVersionsInLibDetector


class FeatureCudaVersionsInLib(PydanticSequence[Version]):
    """
    A sequence of subdirectories of `lib` named after CUDA versions present in a CUDA redistributable package.
    """

    @classmethod
    def of(cls, store_path: Path) -> Self:
        paths: Sequence[Path] | None = CudaVersionsInLibDetector().find(store_path)
        return cls([path.as_posix() for path in paths or []])
