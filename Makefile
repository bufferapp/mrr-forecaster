NAME = grc.io/buffer-data/mrr-forecaster:0.2.0

all: run

build:
	docker build -t $(NAME) .

run: build
	docker run -it --rm --env-file .env $(NAME)

push: build
	docker push $(NAME)

dev: build
	docker run -v $(PWD):/app -it --rm --env-file .env $(NAME) bash

deploy:
	gcloud builds submit --config cloudbuild.yaml .
