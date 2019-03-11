PROJECT = emqx_psk_file
PROJECT_DESCRIPTION = EMQX PSK plugin from a file

DEPS = emqx
dep_emqx = git https://github.com/emqx/emqx

BUILD_DEPS = emqx cuttlefish
dep_cuttlefish = git https://github.com/emqx/cuttlefish

ERLC_OPTS += +debug_info

TEST_ERLC_OPTS += +debug_info

NO_AUTOPATCH = cuttlefish

COVER = true

include $(if $(ERLANG_MK_FILENAME),$(ERLANG_MK_FILENAME),erlang.mk)

app:: rebar.config

app.config::
	./deps/cuttlefish/cuttlefish -l info -e etc/ -c etc/emqx_psk_file.conf -i priv/emqx_psk_file.schema -d data
