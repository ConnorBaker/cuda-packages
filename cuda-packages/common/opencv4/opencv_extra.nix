{
  fetchFromGitHub,
  opencv4,
}:
fetchFromGitHub {
  owner = "opencv";
  repo = "opencv_extra";
  tag = opencv4.version;
  hash = "";
}
