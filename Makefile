NAME = bufferapp/mrr-forecaster:0.1.0

all: run

build:
	docker build -t $(NAME) .

run: build
	docker run -it --rm --env-file .env $(NAME)

dev: build
	docker run -v $(PWD):/app -it --rm --env-file .env $(NAME) bash
