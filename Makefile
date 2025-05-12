.PHONY: all blog serve

all: blog

# Generate blog with hugo
blog:
	make clean
	@hugo -s blog

# Serve blog locally
serve:
	make clean
	hugo server -D --disableFastRender -s blog

# Clean generated blog
clean:
	@rm -Rf blog/public
