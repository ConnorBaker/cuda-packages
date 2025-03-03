from abc import ABC, abstractmethod
from pathlib import Path
from typing import Generic, TypeVar

T = TypeVar("T")


class FeatureDetector(ABC, Generic[T]):
    """
    A generic feature detector which can detect the presence of a type `T` within a Nix store path.

    1. Retrieves a list of paths of interest using `gather`.
    2. Applies
    """

    @abstractmethod
    def find(self, store_path: Path) -> T | None:
        raise NotImplementedError

    def detect(self, store_path: Path) -> bool:
        return self.find(store_path) is not None
