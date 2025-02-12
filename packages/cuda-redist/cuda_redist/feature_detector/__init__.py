from functools import partial
from pathlib import Path
from typing import Any

from pydantic import BaseModel

from .cuda_versions_in_lib import FeatureCudaVersionsInLib
from .outputs import FeatureOutputs


def process_store_path(store_path: Path) -> dict[str, Any]:
    outputs = FeatureOutputs.of(store_path)
    cuda_versions_in_lib = FeatureCudaVersionsInLib.of(store_path)
    dump_model = partial(BaseModel.model_dump, by_alias=True, exclude_none=True, exclude_unset=True, mode="json")
    return {
        "outputs": dump_model(outputs),
        "cudaVersionsInLib": dump_model(cuda_versions_in_lib) if cuda_versions_in_lib else None,
    }
