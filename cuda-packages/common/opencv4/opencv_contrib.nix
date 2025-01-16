{
  fetchFromGitHub,
  opencv4,
}:
fetchFromGitHub {
  owner = "opencv";
  repo = "opencv_contrib";
  tag = opencv4.version;
  hash = "sha256-YNd96qFJ8SHBgDEEsoNps888myGZdELbbuYCae9pW3M=";
}
