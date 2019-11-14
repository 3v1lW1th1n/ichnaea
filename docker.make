# This makefile is executed from inside the docker container.

HERE = $(shell pwd)
PYTHON = $(shell which python)
PIP = $(shell which pip)

VENDOR = $(HERE)/vendor

DATAMAPS_COMMIT = 76e620adabbedabd6866b23b30c145b53bae751e
DATAMAPS_NAME = datamaps-$(DATAMAPS_COMMIT)
DATAMAPS_DIR = $(VENDOR)/$(DATAMAPS_NAME)

LIBMAXMIND_VERSION = 1.3.2
LIBMAXMIND_NAME = libmaxminddb-$(LIBMAXMIND_VERSION)
LIBMAXMIND_DIR = $(VENDOR)/$(LIBMAXMIND_NAME)

TESTS ?= ichnaea
ifeq ($(TESTS), ichnaea)
	TEST_ARG = --cov-config=.coveragerc --cov=ichnaea ichnaea
else
	TEST_ARG = $(TESTS)
endif

.PHONY: all build_datamaps build_libmaxmind build_deps \
	build_python_deps build_ichnaea build_check \
	docs

all:
	@echo "No default make step."

build_datamaps:
	cd $(VENDOR); tar zxf $(DATAMAPS_NAME).tar.gz
	cd $(DATAMAPS_DIR); make -s all
	cp $(DATAMAPS_DIR)/encode /usr/local/bin/
	cp $(DATAMAPS_DIR)/enumerate /usr/local/bin/
	cp $(DATAMAPS_DIR)/merge /usr/local/bin/
	cp $(DATAMAPS_DIR)/render /usr/local/bin/
	rm -rf $(DATAMAPS_DIR)

build_libmaxmind:
	cd $(VENDOR); tar xzf $(LIBMAXMIND_NAME).tar.gz
	cd $(LIBMAXMIND_DIR); ./configure && make -s && make install
	ldconfig
	rm -rf $(LIBMAXMIND_DIR)

build_deps: build_datamaps build_libmaxmind

build_python_deps:
	$(PIP) install --no-cache-dir --disable-pip-version-check --require-hashes \
	    -r requirements/default.txt
	$(PIP) check --disable-pip-version-check

build_geocalc:
	@which cythonize
	cythonize -f geocalclib/geocalc.pyx
	cd geocalclib && $(PIP) install --no-cache-dir --disable-pip-version-check .

build_check:
	@which encode enumerate merge render pngquant
	$(PYTHON) -c "import sys; from shapely import speedups; sys.exit(not speedups.available)"
	$(PYTHON) -c "import geocalc"
	$(PYTHON) -c "import sys; from ichnaea.geoip import GeoIPWrapper; sys.exit(not GeoIPWrapper('ichnaea/tests/data/GeoIP2-City-Test.mmdb').check_extension())"
	$(PYTHON) -c "import sys; from ichnaea.geocode import GEOCODER; sys.exit(not GEOCODER.region(51.5, -0.1) == 'GB')"
