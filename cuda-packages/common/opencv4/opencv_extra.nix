{
  fetchFromGitHub,
  opencv4,
}:
fetchFromGitHub {
  owner = "opencv";
  repo = "opencv_extra";
  rev = "refs/tags/${opencv4.version}";
  hash = "";
}
