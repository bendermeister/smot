deploy:
	cd frontend && gleam run -m lustre/dev build
	docker buildx build . -t smot
