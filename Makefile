GITHUB_USER=Avramenko-Vitaliy
REPO=rd-fluxcd-lesson
DEV=development
PROD=production

bootstrap:
	flux bootstrap github \
      --owner=$(GITHUB_USER) \
      --repository=$(REPO) \
      --branch=main \
      --path=./clusters/rd-cluster \
      --personal

watch:
	flux get ks -w

rc-dev:
	flux reconcile ks app-dev

rc-prod:
	flux reconcile ks app-prod

rc-fs:
	flux reconcile ks flux-system

rc: rc-dev rc-prod rc-fs

prod-pods:
	kubectl get pods -n $(PROD)

prod-dev:
	kubectl get pods -n $(DEV)
