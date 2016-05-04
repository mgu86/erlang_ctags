MODULE=erlang_ctags

all: escript
	@echo "Done"

escript:
	escript gen_escript.erl ${MODULE}
	chmod +x ${MODULE}
	@echo "Escript file '${MODULE}' generated"

clean:
	rm ${MODULE}


