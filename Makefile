BINARY  := claude-dashboard
LDFLAGS := -ldflags "-s -w"

.PHONY: build run test lint install clean

build:
	go build $(LDFLAGS) -o $(BINARY) .

run: build
	./$(BINARY)

test:
	go test ./...

lint:
	golangci-lint run ./...

install:
	go install $(LDFLAGS) .

clean:
	rm -f $(BINARY)

copy:
	cp $(BINARY) $(HOME)/bin/
