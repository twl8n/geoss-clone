# Automatically generated by mmake; do not edit!

default: \
dvi

dvi: \
public_user.dvi

mkdvipdf: \
warn-auto.sh conf-paper
	( cat warn-auto.sh; \
	echo exec dvipdfm -o '$$1.pdf' -p "`head -n 1 conf-paper`" '$$1.dvi' \
	) > mkdvipdf
	chmod 755 mkdvipdf

mkdvips: \
warn-auto.sh conf-paper conf-dvips
	( cat warn-auto.sh; \
	echo exec "`head -n 1 conf-dvips`" \
	-t "`head -n1 conf-paper`" \
	-o '$$1.ps' '$$1.dvi' \
	) > mkdvips
	chmod 755 mkdvips

mklatex: \
conf-latex warn-auto.sh mklatex.sh
	cat warn-auto.sh mklatex.sh \
	  | sed s}@LATEX@}"`head -n 1 conf-latex`"}g \
	  > mklatex
	chmod 755 mklatex

pdf: \
public_user.pdf

ps: \
public_user.ps

public_user.dvi: \
mklatex public_user.tex compactslide.cls
	./mklatex public_user.tex

public_user.pdf: \
public_user.dvi mkdvipdf
	./mkdvipdf public_user

public_user.ps: \
public_user.dvi mkdvips
	./mkdvips public_user

clean:
	rm -rf `cat TARGETS`
