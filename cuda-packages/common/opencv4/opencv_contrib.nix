{
  fetchFromGitHub,
  opencv4,
}:
fetchFromGitHub {
  owner = "opencv";
  repo = "opencv_contrib";
  tag = opencv4.version;
  hash = "sha256-JFSQQRvcZ+aiLUxXqfODaWQW635Xkkvh4xmkNcGySh8=";
}
