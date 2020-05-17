# Makefile for python-openzwave
#

# You can set these variables from the command line.
ARCHBASE      = archive
ARCHIVES      = archives
BUILDDIR      = build
DISTDIR       = dists
NOSEOPTS      = --verbosity=2
NOSECOVER     = --cover-package=openzwave,pyozwman,pyozwweb --with-coverage --cover-inclusive --cover-tests --cover-html --cover-html-dir=docs/html/coverage --with-html --html-file=docs/html/nosetests/nosetests.html
PYLINT        = $(shell which pylint)
PYLINTOPTS    = --max-line-length=140 --max-args=9 --extension-pkg-whitelist=zmq --ignored-classes=zmq --min-public-methods=0

-include CONFIG.make

ifndef PYTHON_EXEC
PYTHON_EXEC=python3
endif

ifndef NOSE_EXEC
NOSE_EXEC=$(shell which nosetests)
endif

ifdef VIRTUAL_ENV
python_version_full := $(wordlist 2,4,$(subst ., ,$(shell ${VIRTUAL_ENV}/bin/${PYTHON_EXEC} --version 2>&1)))
else
python_version_full := $(wordlist 2,4,$(subst ., ,$(shell ${PYTHON_EXEC} --version 2>&1)))
endif

python_openzwave_version := $(shell ${PYTHON_EXEC} pyozw_version.py)

python_version_major = $(word 1,${python_version_full})
python_version_minor = $(word 2,${python_version_full})
python_version_patch = $(word 3,${python_version_full})

PIP_EXEC=pip
ifeq (${python_version_major},3)
	PIP_EXEC=pip3
endif

WHL_PYTHON3 := $(shell ls dist/*.whl 2>/dev/null|grep ${python_openzwave_version}|grep [0-9]-cp3)

ARCHNAME     = python-openzwave-${python_openzwave_version}
ARCHDIR      = ${ARCHBASE}/${ARCHNAME}

.PHONY: help clean all update develop install install-api uninstall clean-docs docs autobuild-tests tests pylint commit developer-deps python-deps autobuild-deps arch-deps common-deps cython-deps check venv-clean venv3

help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  build           : build python-openzwave and openzwave"
	@echo "  develop         : install python-openzwave for developers"
	@echo "  install         : install python-openzwave for users"
	@echo "  install-api     : install python-openzwave (API only) for users"
	@echo "  uninstall       : uninstall python-openzwave"
	@echo "  developer-deps  : install dependencies for developers"
	@echo "  deps            : install dependencies for users"
	@echo "  docs            : make documentation"
	@echo "  tests           : launch tests"
	@echo "  commit          : publish python-openzwave updates on GitHub"
	@echo "  clean           : clean the development directory"
	@echo "  update          : update sources of python-openzwave and openzwave"

clean: clean-docs clean-archive
	-rm -rf $(BUILDDIR)
	-find . -name \*.pyc -delete
	-cd openzwave && $(MAKE) clean
	${PYTHON_EXEC} setup-lib.py clean --all --build-base $(BUILDDIR)/lib
	${PYTHON_EXEC} setup-api.py clean --all --build-base $(BUILDDIR)/api
	${PYTHON_EXEC} setup-manager.py clean --all --build-base $(BUILDDIR)/manager
	${PYTHON_EXEC} setup-web.py clean --all --build-base $(BUILDDIR)/web
	${PYTHON_EXEC} setup.py clean --all --build-base $(BUILDDIR)/python_openzwave
	-rm -f lib/libopenzwave.cpp
	-rm -f libopenzwave.so
	-rm src-lib/libopenzwave/libopenzwave.cpp
	-rm -rf debian/python-openzwave-api/
	-rm -rf debian/python-openzwave-doc/
	-rm -rf debian/python-openzwave-lib/
	-rm -rf debian/python-openzwave-manager/
	-rm -rf debian/python-openzwave-web/
	-rm debian/files
	-rm debian/*.debhelper
	-rm debian/*.debhelper.log
	-rm debian/*.substvars
	-rm -rf .tests_user_path/
	-rm -rf openzwave-git
	-rm -rf openzwave-embed
	-rm -rf open-zwave-hass
	-rm -rf dist
	-rm -rf tmp
	-rm -rf venv3

uninstall:
	-rm -rf $(BUILDDIR)
	-rm -rf $(DISTDIR)
	-yes | ${PIP_EXEC} uninstall python-openzwave-lib
	-yes | ${PIP_EXEC} uninstall python-openzwave-api
	-yes | ${PIP_EXEC} uninstall libopenzwave
	-yes | ${PIP_EXEC} uninstall openzwave
	-yes | ${PIP_EXEC} uninstall pyozwman
	-yes | ${PIP_EXEC} uninstall pyozwweb
	-yes | ${PIP_EXEC} uninstall python_openzwave
	${PYTHON_EXEC} setup-lib.py develop --uninstall --flavor=dev
	${PYTHON_EXEC} setup-api.py develop --uninstall
	${PYTHON_EXEC} setup-manager.py develop --uninstall
	${PYTHON_EXEC} setup-web.py develop --uninstall
	${PYTHON_EXEC} setup.py develop --uninstall --flavor=dev
	-rm -f libopenzwave.so
	-rm -f src-lib/libopenzwave*.so
	-rm -f libopenzwave/liopenzwave.so
	-rm -Rf python_openzwave_api.egg-info/
	-rm -Rf src-api/python_openzwave_api.egg-info/
	-rm -Rf src-api/openzwave.egg-info/
	-rm -Rf src-manager/pyozwman.egg-info/
	-rm -Rf homeassistant_pyozw.egg-info/
	-rm -Rf src-lib/python_openzwave_lib.egg-info/
	-rm -Rf src-lib/libopenzwave.egg-info/
	-rm -Rf src-web/pyozwweb.egg-info/
	-rm -Rf /usr/local/lib/python${python_version_major}.${python_version_minor}/dist-packages/python-openzwave*
	-rm -Rf /usr/local/lib/python${python_version_major}.${python_version_minor}/dist-packages/python_openzwave*
	-rm -Rf /usr/local/lib/python${python_version_major}.${python_version_minor}/dist-packages/libopenzwave*
	-rm -Rf /usr/local/lib/python${python_version_major}.${python_version_minor}/dist-packages/openzwave*
	-rm -Rf /usr/local/lib/python${python_version_major}.${python_version_minor}/dist-packages/pyozwman*
	-rm -Rf /usr/local/lib/python${python_version_major}.${python_version_minor}/dist-packages/pyozwweb*
	-rm -Rf /usr/local/share/python-openzwave
	-rm -Rf /usr/local/share/openzwave

developer-deps: common-deps cython-deps tests-deps pip-deps doc-deps
	@echo
	@echo "Dependencies for developers of python-openzwave installed (python ${python_version_full})"

repo-deps: common-deps cython-deps tests-deps pip-deps
	@echo
	@echo "Dependencies for users installed (python ${python_version_full})"

autobuild-deps: common-deps cython-deps tests-deps pip-deps
	apt-get install --force-yes -y git
	@echo
	@echo "Dependencies for autobuilders (docker, travis, ...) installed (python ${python_version_full})"

arch-deps: common-deps pip-deps
	@echo
	@echo "Dependencies for users installed (python ${python_version_full})"

python-deps:
ifeq (${python_version_major},2)
	apt-get install --force-yes -y python2.7 python2.7-dev python2.7-minimal libyaml-dev python-pip
endif
ifeq (${python_version_major},3)
	apt-get install --force-yes -y python3 python3-dev python3-minimal libyaml-dev python3-pip
endif

cython-deps:
ifeq (${python_version_major},2)
	apt-get install --force-yes -y cython
endif
ifeq (${python_version_major},3)
	apt-get install --force-yes -y cython3
endif

ci-deps:
	apt-get install --force-yes -y python-pip python-dev python-docutils python-setuptools python-virtualenv
	-apt-get install --force-yes -y python3-pip python3-docutils python3-dev python3-setuptools
	apt-get install --force-yes -y build-essential libudev-dev g++ libyaml-dev

common-deps:
	@echo Installing dependencies for python : ${python_version_full}
ifeq (${python_version_major},2)
	apt-get install --force-yes -y python-pip python-dev python-docutils python-setuptools
endif
ifeq (${python_version_major},3)
	-apt-get install --force-yes -y python3-pip python3-docutils python3-dev python3-setuptools
endif
	apt-get install --force-yes -y build-essential libudev-dev g++ libyaml-dev

tests-deps:
	${PIP_EXEC} install nose-html
	${PIP_EXEC} install nose-progressive
	${PIP_EXEC} install coverage
	${PIP_EXEC} install nose
	${PIP_EXEC} install pylint

doc-deps:
	-apt-get install --force-yes -y python-sphinx
	${PIP_EXEC} install cython sphinxcontrib-blockdiag sphinxcontrib-actdiag sphinxcontrib-nwdiag sphinxcontrib-seqdiag

pip-deps:
	#${PIP_EXEC} install docutils
	#${PIP_EXEC} install setuptools
	#The following line crashes with a core dump
	#${PIP_EXEC} install "Cython==0.22"

clean-docs:
	cd docs && $(MAKE) clean
	-rm -Rf docs/html
	-rm -Rf docs/joomla
	-rm -Rf docs/pdf

docs: clean-docs
	cd docs && $(MAKE) docs
	cp docs/README.rst README.rst
	cp docs/INSTALL_REPO.rst .
	cp docs/INSTALL_ARCH.rst .
	cp docs/INSTALL_MAC.rst .
	cp docs/INSTALL_WIN.rst .
	cp docs/_build/text/COPYRIGHT.txt .
	cp docs/_build/text/COPYRIGHT.txt LICENSE.txt
	cp docs/_build/text/CHANGELOG.txt .
	cp docs/_build/text/DEVEL.txt .
	cp docs/_build/text/EXAMPLES.txt .

	@echo
	@echo "Documentation finished."

install-lib:
	${PYTHON_EXEC} setup-lib.py install --flavor=git
	@echo
	@echo "Installation of lib finished."

install-api: install-lib
	${PYTHON_EXEC} setup-api.py install
	@echo
	@echo "Installation of API finished."

install-manager: install-api
	${PYTHON_EXEC} setup-manager.py install
	@echo
	@echo "Installation of manager finished."

install: install-manager
	${PYTHON_EXEC} setup-web.py install
	@echo
	@echo "Installation for users finished."

develop: src-lib/libopenzwave/libopenzwave.cpp
	${PYTHON_EXEC} setup-lib.py develop --flavor=dev
	${PYTHON_EXEC} setup-api.py develop
	${PYTHON_EXEC} setup-manager.py develop
	${PYTHON_EXEC} setup-web.py develop
	${PYTHON_EXEC} setup.py develop --flavor=dev
	@echo
	@echo "Installation for developers of python-openzwave finished."

tests:
	export NOSESKIP=False && ${NOSE_EXEC} $(NOSEOPTS) tests/; unset NOSESKIP

	@echo
	@echo "Tests for ZWave network finished."

autobuild-tests:
	${NOSE_EXEC} $(NOSEOPTS) tests/lib/autobuild tests/api/autobuild
	@echo
	@echo "Autobuild-tests for ZWave network finished."

pylint:
	$(PYLINT) $(PYLINTOPTS) src-lib/libopenzwave/ src-api/openzwave/ src-manager/pyozwman/ src-web/pyozwweb/
	@echo
	@echo "Pylint finished."

update: openzwave
	git pull
	cd openzwave && git pull

build: openzwave/.lib/
	${PYTHON_EXEC} setup-lib.py build --flavor=dev

src-lib/libopenzwave/libopenzwave.cpp: openzwave/.lib/
	${PYTHON_EXEC} setup-lib.py build --flavor=dev

openzwave:
	git clone -b hass https://github.com/mpenick/open-zwave.git openzwave

openzwave.gzip:
	wget --no-check-certificate https://codeload.github.com/home-assistant/open-zwave/zip/hass
	mv hass open-zwave-hass.zip
	unzip open-zwave-hass.zip
	mv open-zwave-hass openzwave

openzwave/.lib/: openzwave
	cd openzwave && $(MAKE) -j 4

clean-archive:
	-rm -rf $(ARCHBASE)

$(ARCHDIR):
	-mkdir -p $(ARCHDIR)/src-lib
	-mkdir -p $(ARCHDIR)/src-api
	-mkdir -p $(ARCHDIR)/src-manager
	-mkdir -p $(ARCHDIR)/src-web
	cp -Rf openzwave $(ARCHDIR)/
	cp -f openzwave/cpp/src/vers.cpp $(ARCHDIR)/openzwave.vers.cpp
	cp -Rf src-lib/libopenzwave $(ARCHDIR)/src-lib
	cp -f src-lib/libopenzwave/libopenzwave.cpp $(ARCHDIR)/src-lib/libopenzwave/
	cp -Rf src-api/openzwave $(ARCHDIR)/src-api
	cp -Rf src-manager/pyozwman $(ARCHDIR)/src-manager
	cp -Rf src-manager/scripts $(ARCHDIR)/src-manager
	cp -Rf src-web/pyozwweb $(ARCHDIR)/src-web
	cp -Rf examples $(ARCHDIR)
	-find $(ARCHDIR) -name \*.pyc -delete
	-find $(ARCHDIR) -name zwcfg_\*.xml -delete
	-find $(ARCHDIR) -name OZW_Log.log -delete
	-find $(ARCHDIR) -name OZW_Log.txt -delete
	-find $(ARCHDIR) -name ozwsh.log -delete
	-find $(ARCHDIR) -name errors.log -delete
	-find $(ARCHDIR) -name zwscene.xml -delete
	-find $(ARCHDIR) -name zwbutton.xml -delete
	-find $(ARCHDIR) -name pyozw.db -delete
	-cd $(ARCHDIR)/openzwave && $(MAKE) clean
	-rm -Rf $(ARCHDIR)/openzwave/.git
	cp -f $(ARCHDIR)/openzwave.vers.cpp $(ARCHDIR)/openzwave/cpp/src/vers.cpp

tgz: clean-archive $(ARCHDIR) docs
	cp docs/_build/text/README.txt $(ARCHDIR)/
	cp docs/_build/text/INSTALL_ARCH.txt $(ARCHDIR)/
	cp docs/_build/text/INSTALL_WIN.txt $(ARCHDIR)/
	cp docs/_build/text/INSTALL_MAC.txt $(ARCHDIR)/
	cp docs/_build/text/COPYRIGHT.txt $(ARCHDIR)/
	cp docs/_build/text/EXAMPLES.txt $(ARCHDIR)/
	cp docs/_build/text/CHANGELOG.txt $(ARCHDIR)/
	mkdir -p $(ARCHDIR)/docs
	cp -Rf docs/_build/html/* $(ARCHDIR)/docs/
	cp Makefile.archive $(ARCHDIR)/Makefile
	cp setup-lib.py $(ARCHDIR)/
	sed -i 's|src-lib/libopenzwave/libopenzwave.pyx|src-lib/libopenzwave/libopenzwave.cpp|g' $(ARCHDIR)/setup-lib.py
	cp setup-api.py $(ARCHDIR)/
	cp setup-manager.py $(ARCHDIR)/
	cp setup-web.py $(ARCHDIR)/
	cp -Rf pyozw_version.py $(ARCHDIR)/pyozw_version.py
	-mkdir -p $(DISTDIR)
	tar cvzf $(DISTDIR)/python-openzwave-${python_openzwave_version}.tgz -C $(ARCHBASE) ${ARCHNAME}
	rm -Rf $(ARCHBASE)
	mv $(DISTDIR)/python-openzwave-${python_openzwave_version}.tgz $(ARCHIVES)/
	@echo
	@echo "Archive for version ${python_openzwave_version} created"

embed_openzave_hass:clean-archive src-lib/libopenzwave/libopenzwave.cpp
	-rm -Rf $(ARCHBASE)/open-zwave-hass
	-mkdir -p $(ARCHBASE)/open-zwave-hass/python-openzwave/src-lib/libopenzwave
	cp -Rf openzwave/* $(ARCHBASE)/open-zwave-hass/
	cp -f openzwave/cpp/src/vers.cpp $(ARCHBASE)/open-zwave-hass/python-openzwave/openzwave.vers.cpp
	cp -f src-lib/libopenzwave/libopenzwave.cpp $(ARCHBASE)/open-zwave-hass/python-openzwave/src-lib/libopenzwave/
	-find $(ARCHBASE)/open-zwave-hass -name \*.pyc -delete 2>/dev/null || true
	-find $(ARCHBASE)/open-zwave-hass -name zwcfg_\*.xml -delete 2>/dev/null || true
	-find $(ARCHBASE)/open-zwave-hass -name OZW_Log.log -delete 2>/dev/null || true
	-find $(ARCHBASE)/open-zwave-hass -name OZW_Log.txt -delete 2>/dev/null || true
	-find $(ARCHBASE)/open-zwave-hass -name ozwsh.log -delete 2>/dev/null || true
	-find $(ARCHBASE)/open-zwave-hass -name errors.log -delete 2>/dev/null || true
	-find $(ARCHBASE)/open-zwave-hass -name zwscene.xml -delete 2>/dev/null || true
	-find $(ARCHBASE)/open-zwave-hass -name zwbutton.xml -delete 2>/dev/null || true
	-find $(ARCHBASE)/open-zwave-hass -name pyozw.db -delete 2>/dev/null || true
	-cd $(ARCHBASE)/open-zwave-hass && $(MAKE) clean
	-rm -Rf $(ARCHBASE)/open-zwave-hass/.git
	-rm -f $(ARCHBASE)/open-zwave-hass/open-zwave-hass.zip
	-rm -Rf $(ARCHBASE)/open-zwave-hass/docs/*
	-cp -f openzwave/docs/default.htm $(ARCHBASE)/open-zwave-hass/docs/*
	-rm -Rf $(ARCHBASE)/open-zwave-hass/dotnet/*
	cp -f $(ARCHBASE)/open-zwave-hass/python-openzwave/openzwave.vers.cpp $(ARCHBASE)/open-zwave-hass/cpp/src/vers.cpp
	-mkdir -p $(DISTDIR)
	cd $(ARCHBASE) && zip -r ../$(DISTDIR)/open-zwave-hass-${python_openzwave_version}.zip open-zwave-hass
	mv $(DISTDIR)/open-zwave-hass-${python_openzwave_version}.zip $(ARCHIVES)/
	@echo
	@echo "embed_openzave_hass for version ${python_openzwave_version} created"

pypi_package:clean-archive
	-rm -Rf $(ARCHBASE)/homeassistant_pyozw/
	${PYTHON_EXEC} setup.py egg_info
	-mkdir -p $(ARCHBASE)/homeassistant_pyozw/
	cp -Rf src-python_openzwave $(ARCHBASE)/homeassistant_pyozw/
	cp -Rf src-lib $(ARCHBASE)/homeassistant_pyozw/
	cp -Rf src-api $(ARCHBASE)/homeassistant_pyozw/
	cp -Rf src-manager $(ARCHBASE)/homeassistant_pyozw/
	cp -f setup.cfg $(ARCHBASE)/homeassistant_pyozw/
	cp -f setup.py $(ARCHBASE)/homeassistant_pyozw/
	cp -f pyozw_pkgconfig.py $(ARCHBASE)/homeassistant_pyozw/
	cp -f pyozw_setup.py $(ARCHBASE)/homeassistant_pyozw/
	cp -f pyozw_version.py $(ARCHBASE)/homeassistant_pyozw/
	cp -f pyozw_win.py $(ARCHBASE)/homeassistant_pyozw/
	cp -f pyozw_progressbar.py $(ARCHBASE)/homeassistant_pyozw/
	cp -f homeassistant_pyozw.egg-info/PKG-INFO $(ARCHBASE)/homeassistant_pyozw/
	-find $(ARCHBASE)/homeassistant_pyozw/ -name \*.pyc -delete 2>/dev/null || true
	-find $(ARCHBASE)/homeassistant_pyozw/ -name \*.so -delete 2>/dev/null || true
	-find $(ARCHBASE)/homeassistant_pyozw/ -type d -name \*.egg-info -exec rm -rf '{}' \; 2>/dev/null || true
	-find $(ARCHBASE)/homeassistant_pyozw/ -name zwcfg_\*.xml -delete
	-find $(ARCHBASE)/homeassistant_pyozw/ -name OZW_Log.log -delete
	-find $(ARCHBASE)/homeassistant_pyozw/ -name OZW_Log.txt -delete
	-find $(ARCHBASE)/homeassistant_pyozw/ -name ozwsh.log -delete
	-find $(ARCHBASE)/homeassistant_pyozw/ -name errors.log -delete
	-find $(ARCHBASE)/homeassistant_pyozw/ -name zwscene.xml -delete
	-find $(ARCHBASE)/homeassistant_pyozw/ -name zwbutton.xml -delete
	-find $(ARCHBASE)/homeassistant_pyozw/ -name pyozw.db -delete
	-rm -f $(ARCHBASE)/homeassistant_pyozw/src-lib/libopenzwave/libopenzwave.cpp
	-mkdir -p $(DISTDIR) || src-lib/
	cd $(ARCHBASE) && zip -r ../$(DISTDIR)/homeassistant_pyozw-${python_openzwave_version}.zip homeassistant_pyozw
	mv $(DISTDIR)/homeassistant_pyozw-${python_openzwave_version}.zip $(ARCHIVES)/
	@echo
	@echo "pypi_package for version ${python_openzwave_version} created"

push: develop
	-git commit -m "Auto-commit for docs" README.rst INSTALL_REPO.rst INSTALL_MAC.rst INSTALL_WIN.rst INSTALL_ARCH.rst COPYRIGHT.txt DEVEL.txt EXAMPLES.txt CHANGELOG.txt docs/
	-git push
	@echo
	@echo "Commits for branch hass pushed on github."

commit: push
	@echo
	@echo "Commits for branches hass pushed on github."

tag:
	git tag v${python_openzwave_version}
	git push origin v${python_openzwave_version}
	@echo
	@echo "Tag pushed on github."

validate-pr: uninstall clean update develop
	@echo '////////////////////////////////////////////////////////////////////////////////////////////'
	@echo '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
	@echo '////////////////////////////////////////////////////////////////////////////////////////////'
	@echo
	@echo
	@echo "Tests to validate a PR"
	@echo
	@echo

	$(MAKE) venv-dev-autobuild-tests
	$(MAKE) venv-bdist_wheel-whl-autobuild-tests
	$(MAKE) venv-bdist_wheel-autobuild-tests
#~ 	$(MAKE) venv-tests

	@echo
	@echo
	@echo "Tests to validate a PR finished"
	@echo
	@echo
	@echo '////////////////////////////////////////////////////////////////////////////////////////////'
	@echo '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
	@echo '////////////////////////////////////////////////////////////////////////////////////////////'
	@echo

new-version: validate-pr
	@echo '////////////////////////////////////////////////////////////////////////////////////////////'
	@echo '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
	@echo '////////////////////////////////////////////////////////////////////////////////////////////'
	@echo '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
	@echo
	@echo
	@echo "Make a new version ${python_openzwave_version}"
	@echo
	@echo

	-$(MAKE) docs
	-git commit -m "Auto-commit for new-version" README.rst INSTALL_REPO.rst INSTALL_MAC.rst INSTALL_WIN.rst INSTALL_ARCH.rst LICENSE.txt COPYRIGHT.txt DEVEL.txt EXAMPLES.txt CHANGELOG.txt docs/
	-git checkout $(ARCHIVES)/
	-git commit -m "Update pyozw_version to ${python_openzwave_version}" pyozw_version.py
	-$(MAKE) embed_openzave_hass
	-$(MAKE) pypi_package
	-git add $(ARCHIVES)/homeassistant_pyozw-${python_openzwave_version}.zip && git commit -m "Add new pypi package" $(ARCHIVES)/homeassistant_pyozw-${python_openzwave_version}.zip && git push
	-git add $(ARCHIVES)/open-zwave-hass-${python_openzwave_version}.zip && git commit -m "Add new embed package" $(ARCHIVES)/open-zwave-hass-${python_openzwave_version}.zip && git push
	-git checkout $(ARCHIVES)/*
	-twine upload archives/homeassistant_pyozw-${python_openzwave_version}.zip -r pypi
	-$(MAKE) tag
	sleep 60
	$(MAKE) venv-pypitest-autobuild-tests
	$(MAKE) venv-pypilive-autobuild-tests

	@echo
	@echo
	@echo "New version ${python_openzwave_version} created and published"
	@echo
	@echo
	@echo '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
	@echo '////////////////////////////////////////////////////////////////////////////////////////////'
	@echo '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
	@echo '////////////////////////////////////////////////////////////////////////////////////////////'
	@echo

venv-deps: common-deps
	apt-get install --force-yes -y python-all python-dev python3-all python3-dev python-virtualenv python-pip
#~ 	apt-get install --force-yes -y python-wheel-common python3-wheel python-wheel python-pip-whl
	apt-get install --force-yes -y pkg-config wget unzip zip
	pip install Cython
	pip install wheel

docker-deps: common-deps
	apt-get install --force-yes -y python-all python-dev python3-all python3-dev python-virtualenv
	apt-get install --force-yes -y python3-pip python-pip python-wheel python3-wheel python-pip-whl
	apt-get install --force-yes -y wget unzip zip
	apt-get install --force-yes -y g++ libudev-dev libyaml-dev
	pip install cython
	pip3 install cython

venv3:
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo "New venv for python3"
	@echo

	virtualenv --python=python3 venv3
	venv3/bin/python --version
	venv3/bin/pip install nose
	venv3/bin/pip install Cython wheel six
	venv3/bin/pip install 'PyDispatcher>=2.0.5'
	chmod 755 venv3/bin/activate
	-rm -f src-lib/libopenzwave/libopenzwave.cpp

	@echo
	@echo "Venv for python3 created"
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

venv3-dev: venv3 src-lib/libopenzwave/libopenzwave.cpp
	venv3/bin/python setup-lib.py develop --flavor=dev
	venv3/bin/python setup-api.py develop
	venv3/bin/python setup-manager.py develop

venv3-install: venv3 src-lib/libopenzwave/libopenzwave.cpp
	venv3/bin/python setup.py install --flavor=dev

venv3-shared: venv3 src-lib/libopenzwave/libopenzwave.cpp
	venv3/bin/python setup-lib.py install --flavor=shared
	venv3/bin/python setup-api.py install
#~ 	venv3/bin/python setup-manager.py install

venv-clean:
	@echo "Clean files in venvs"
	-rm -rf venv3
	-rm -f src-lib/libopenzwave/libopenzwave.cpp

venv-tests: venv3-tests

venv3-tests: venv3-dev
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	-$(MAKE) PYTHON_EXEC=venv3/bin/python NOSE_EXEC=venv3/bin/nosetests tests

	@echo
	@echo
	@echo "Tests for venv3 done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-autobuild-tests: clean
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-autobuild-autobuild-tests."
	@echo
	@echo

	$(MAKE) venv-pypitest-autobuild-tests
	$(MAKE) venv-pypilive-autobuild-tests
	$(MAKE) venv-embed-autobuild-tests
	$(MAKE) venv-bdist_wheel-whl-autobuild-tests
	$(MAKE) venv-bdist_wheel-autobuild-tests
	$(MAKE) venv-pypi-autobuild-tests
	$(MAKE) venv-dev-autobuild-tests
	$(MAKE) venv-git-autobuild-tests

	@echo
	@echo
	@echo "Tests for venv-autobuild-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-continuous-autobuild-tests:
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-continuous-autobuild-tests."
	@echo
	@echo

	-$(MAKE) venv-embed-autobuild-tests
	-$(MAKE) venv-embed_shared-autobuild-tests
	-$(MAKE) venv-git-autobuild-tests
	-$(MAKE) venv-git_shared-autobuild-tests
	-$(MAKE) venv-bdist_wheel-whl-autobuild-tests
	-$(MAKE) venv-bdist_wheel-autobuild-tests
	-$(MAKE) venv-pypi-autobuild-tests

	@echo
	@echo
	@echo "Tests for venv-continuous-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-git-autobuild-tests: venv-clean venv3
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-git-autobuild-tests."
	@echo
	@echo

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	venv3/bin/python setup-lib.py install --flavor=git
	venv3/bin/python setup-api.py install
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild
	venv3/bin/python  venv3/bin/pyozw_check
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(git-'

	@echo
	@echo
	@echo "Tests for venv-git-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-pypitest-autobuild-tests: venv-clean venv3
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-pypitest-autobuild-tests."
	@echo
	@echo

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	-rm -f libopenzwave*.so
	venv3/bin/pip install "urwid>=1.1.1"
	venv3/bin/pip install -i https://testpypi.python.org/pypi -vvv python_openzwave
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(embed-'
	venv3/bin/pip install "Cython"
	venv3/bin/pip uninstall python_openzwave -y
	venv3/bin/pip install -i https://testpypi.python.org/pypi -vvv python_openzwave --install-option="--flavor=git"
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	venv3/bin/pip install -i https://testpypi.python.org/pypi -vvv python_openzwave --force --install-option="--flavor=git"
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	venv3/bin/python  venv3/bin/pyozw_check
	venv3/bin/python  venv3/bin/pyozw_shell --help
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(git-'
	venv3/bin/pip uninstall python_openzwave -y

	-rm -f libopenzwave*.so
	@echo
	@echo "Tests for venv-pypitest-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-pypilive-autobuild-tests: venv-clean
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-pypilive-autobuild-tests."
	@echo
	@echo

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	-rm -Rf venv3/
	virtualenv --python=python3 venv3
	chmod 755 venv3/bin/activate
	-rm -f src-lib/libopenzwave/libopenzwave.cpp
	-rm -f libop1enzwave*.so
	venv3/bin/pip install "nose"
	venv3/bin/pip install "urwid>=1.1.1"
	venv3/bin/pip install -vv python_openzwave
	venv3/bin/python venv3/bin/pyozw_check -o raw
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(embed-'
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	venv3/bin/pip install Cython
	venv3/bin/pip uninstall python_openzwave -y
	venv3/bin/pip install -vv python_openzwave --upgrade --install-option="--flavor=git"
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	venv3/bin/python venv3/bin/pyozw_check -o raw
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(git-'
	venv3/bin/pip uninstall python_openzwave -y
	venv3/bin/pip install -vv python_openzwave --upgrade --install-option="--flavor=ozwdev"
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	venv3/bin/python venv3/bin/pyozw_check -o raw
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(ozwdev-'
	venv3/bin/pip uninstall python_openzwave -y

	-rm -f libopenzwave*.so
	@echo
	@echo "Tests for venv-pypilive-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-git_shared-autobuild-tests: venv-clean venv3
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-git_shared-autobuild-tests."
	@echo
	@echo

	$(MAKE) uninstall
	$(MAKE) uninstallso
	-pkg-config --libs libopenzwave

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	venv3/bin/python setup-lib.py install --flavor=git_shared
	venv3/bin/python setup-api.py install
#~ 	venv3/bin/python setup-manager.py install
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild
	find /usr/local/etc/openzwave -iname device_classes.xml -type f -exec cat '{}' \;|grep open-zwave
	test -f venv3/lib/python*/site-packages/libopenzwave*.so
	venv3/bin/python  venv3/bin/pyozw_check
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(git_shared-'
	pkg-config --libs libopenzwave

	@echo
	@echo
	@echo "Tests for venv-git-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-embed-autobuild-tests: venv-clean venv3
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-embed-autobuild-tests."
	@echo
	@echo

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	-rm -f libopenzwave*.so
	venv3/bin/pip uninstall -y wheel
	venv3/bin/pip install "urwid>=1.1.1"
	venv3/bin/pip uninstall -y Cython
	venv3/bin/python setup.py install --flavor=embed
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	test -f venv3/lib/python*/site-packages/libopenzwave*.so
	venv3/bin/python  venv3/bin/pyozw_check
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(embed-'

	-rm -f libopenzwave*.so
	@echo
	@echo
	@echo "Tests for venv-embed-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-embed_shared-autobuild-tests: venv-clean venv3
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-embed_shared-autobuild-tests."
	@echo
	@echo

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	-rm -f libopenzwave*.so
	venv3/bin/pip install "urwid>=1.1.1"
	venv3/bin/pip uninstall -y Cython
	venv3/bin/python setup.py install --flavor=embed_shared
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	test -f venv3/lib/python*/site-packages/libopenzwave*.so
	venv3/bin/python  venv3/bin/pyozw_check
	venv3/bin/python venv3/bin/pyozw_check -o raw|grep '(embed_shared-'

	-rm -f libopenzwave*.so
	@echo
	@echo
	@echo "Tests for venv-embed-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-pypi-autobuild-tests: venv-clean pypi_package
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-pypi-autobuild-tests."
	@echo
	@echo

	-rm -f dist/*.whl
	-rm -Rf tmp/pypi_test/
	-mkdir -p tmp/pypi_test/
	cd tmp/pypi_test/ && unzip ../../$(ARCHIVES)/homeassistant_pyozw-${python_openzwave_version}.zip

	virtualenv --python=python3 venv3
	chmod 755 venv3/bin/activate
	-rm -f src-lib/libopenzwave/libopenzwave.cpp
	-rm -f libop1enzwave*.so
	venv3/bin/pip install "wheel"
	venv3/bin/pip install "urwid>=1.1.1"
	venv3/bin/pip install "Cython"

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	. venv3/bin/activate && cd tmp/pypi_test/python_openzwave && python setup.py bdist_wheel --flavor=git

	-mkdir -p dist
	cp tmp/pypi_test/python_openzwave/dist/*.whl dist/

	$(MAKE) venv-bdist_wheel-autobuild-tests

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	. venv3/bin/activate && cd tmp/pypi_test/python_openzwave && python setup.py install --force --flavor=git
	. venv3/bin/activate && python venv3/bin/pyozw_check
	. venv3/bin/activate && cd tmp/pypi_test/python_openzwave && python setup.py clean --all --flavor=git
	find venv3/lib/ -iname device_classes.xml -type f -print|cat

	@echo
	@echo
	@echo "Tests for venv-pypi-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-bdist_wheel-whl-autobuild-tests: venv-clean venv3
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Create tests whl for venv-bdist_wheel-autobuild-tests."
	@echo
	@echo

	-rm -f dist/*.whl

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	venv3/bin/python setup.py install --flavor=git
	venv3/bin/python setup.py bdist_wheel --flavor=git

	@echo
	@echo
	@echo "Tests for venv-bdist_wheel-autobuild-tests created."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-bdist_wheel-autobuild-tests: venv-clean
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-bdist_wheel-autobuild-tests."
	@echo
	@echo

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	-rm -Rf venv3
	virtualenv --python=python3 venv3
	chmod 755 venv3/bin/activate
	-rm -f src-lib/libopenzwave/libopenzwave.cpp
	-rm -f libopenzwave*.so

	venv3/bin/pip install "nose"
	venv3/bin/pip install "urwid>=1.1.1"
	venv3/bin/pip install dist/homeassistant_pyozw-${python_openzwave_version}-cp3*
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild tests/manager/autobuild
	find venv3/lib/ -iname device_classes.xml -type f -exec cat '{}' \;|grep open-zwave
	test -f venv3/lib/python*/site-packages/libopenzwave*.so
	venv3/bin/pip uninstall -y "${WHL_PYTHON3}"

	@echo
	@echo
	@echo "Tests for venv-bdist_wheel-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-dev-autobuild-tests: venv-clean venv3 src-lib/libopenzwave/libopenzwave.cpp
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-dev-autobuild-tests."
	@echo
	@echo

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	-rm -f libopenzwave*.so

	#PIP like
	venv3/bin/python3 -u -c "import setuptools, tokenize;__file__='setup.py';f=getattr(tokenize, 'open', open)(__file__);code=f.read().replace('\r\n', '\n');f.close();exec(compile(code, __file__, 'exec'))" install --record /tmp/install-record.txt --single-version-externally-managed --compile --install-headers venv3/include/site/python3.5/python-openzwave "--flavor=git"

	rm -f src-lib/libopenzwave/libopenzwave.cpp
	venv3/bin/python setup-lib.py install --flavor=dev
	venv3/bin/python setup-api.py install
	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild
	venv3/bin/python  venv3/bin/pyozw_check

	-rm -f libopenzwave*.so
	@echo
	@echo
	@echo "Tests for venv-dev-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

venv-shared-autobuild-tests: venv-clean venv3-shared
	@echo ==========================================================================================
	@echo
	@echo
	@echo "Launch tests for venv-shared-autobuild-tests."
	@echo
	@echo

	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo
	@echo Tests for python3
	@echo
	@echo ////////////////////////////////////////////////////////////////////////////////////////////
	@echo

	venv3/bin/nosetests --verbose tests/lib/autobuild tests/api/autobuild
	venv3/bin/python  venv3/bin/pyozw_check

	@echo
	@echo
	@echo "Tests for venv-shared-autobuild-tests done."
	@echo
	@echo
	@echo ==========================================================================================
	@echo

buildso: openzwave/.lib/
	cd openzwave && $(MAKE) install

uninstallso:
	rm -f /usr/local/lib/x86_64-linux-gnu/pkgconfig/libopenzwave.pc
	rm -f /usr/local/lib64/libopenzwave.so.1.4
	rm -f /usr/local/lib64/libopenzwave.so
	rm -Rf /usr/local/include/openzwave
	rm -Rf /usr/local/etc/openzwave
	rm -Rf /usr/local/share/doc/openzwave*
	-find /usr/local/lib/pkgconfig/ -iname libopenzwave.pc -delete

pyozw_pkgconfig.py:
	wget https://raw.githubusercontent.com/matze/pkgconfig/master/pkgconfig/pkgconfig.py
	mv pkgconfig.py pyozw_pkgconfig.py
