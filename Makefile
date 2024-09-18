################################################################################
# Prepare

.EXPORT_ALL_VARIABLES:
.ONESHELL:
.DELETE_ON_ERROR:
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
SHELL := bash

################################################################################

DIR_ROOT := $(abspath ./)
DIR_ROCKSDB_EBIN := $(DIR_ROOT)/erlang-rocksdb/_build/default/lib/rocksdb/ebin

TARGET_ROCKSDB_EBIN := $(DIR_ROOT)/erlang-rocksdb/_build/default/lib/rocksdb/ebin/rocksdb.beam
TARGET_WRITE_ESCRIPT := $(DIR_ROOT)/write.erl
TARGET_ROCKSDB_DB := $(DIR_ROOT)/db

BIN_ESCRIPT := $(shell which escript)

$(TARGET_ROCKSDB_EBIN):
	cd erlang-rocksdb && $(MAKE)

.PHONY: write
write: $(TARGET_ROCKSDB_EBIN)
	$(BIN_ESCRIPT) write.erl $(TARGET_ROCKSDB_DB)

.PHONY: read
read: $(TARGET_ROCKSDB_EBIN)
	$(BIN_ESCRIPT) read.erl $(TARGET_ROCKSDB_DB)

.PHONY: test
test: $(TARGET_ROCKSDB_EBIN) clean
	@while true; do \
		echo "Starting write.erl script..."; \
		$(BIN_ESCRIPT) write.erl $(TARGET_ROCKSDB_DB) & \
		WRITE_PID=$$!; \
		SLEEP_TIME=$$(shuf -i 1-10 -n 1); \
		echo "Sleeping for $$SLEEP_TIME seconds (pid $$WRITE_PID)..."; \
		sleep $$SLEEP_TIME; \
		echo "Killing write.erl script..."; \
		kill -9 $$WRITE_PID; \
		wait $$WRITE_PID 2>/dev/null || true; \
		echo "Running read.erl script..."; \
		if $(BIN_ESCRIPT) read.erl $(TARGET_ROCKSDB_DB); then \
			echo "Database check passed. Repeating..."; \
		else \
			echo "Database check failed. Exiting..."; \
			exit 1; \
		fi; \
	done

.PHONY: clean
clean:
	rm -rf $(TARGET_ROCKSDB_DB)
