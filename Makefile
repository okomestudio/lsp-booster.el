target_exec := emacs-lsp-booster
version := 0.2.1

build_dir := ./build
target_path := $(shell dirname $(shell which emacs))

src_repo := https://github.com/blahgeek/emacs-lsp-booster
src_path := releases/download/v$(version)
src_file := emacs-lsp-booster_v$(version)_x86_64-unknown-linux-musl.zip
src_url := $(src_repo)/$(src_path)/$(src_file)

$(target_path)/$(target_exec): $(build_dir)/$(target_exec)
	cp $(build_dir)/$(target_exec) $(target_path)/$(target_exec)

$(build_dir)/$(target_exec): $(build_dir)/$(src_file)
	unzip -o $(build_dir)/$(src_file) -d "${build_dir}"

$(build_dir)/$(src_file):
	mkdir -p $(dir $@)
	curl -L -O "${src_url}" --output-dir "${build_dir}"

.PHONY: uninstall
uninstall:
	rm $(target_path)/$(target_exec)

.PHONY: clean
clean:
	rm -rf $(build_dir)
