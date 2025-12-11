GITHUB_USER=Avramenko-Vitaliy
REPO=rd-fluxcd-lesson

bootstrap:
	flux bootstrap github \
      --owner=$(GITHUB_USER) \
      --repository=$(REPO) \
      --branch=main \
      --path=./clusters/rd-cluster \
      --personal
