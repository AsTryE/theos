ifeq ($(FW_PACKAGING_RULES_LOADED),)
FW_PACKAGING_RULES_LOADED := 1

.PHONY: package before-package internal-package after-package-buildno after-package

package:: all before-package internal-package after-package

FAKEROOT := $(FW_SCRIPTDIR)/fakeroot.sh -p "$(FW_PROJECT_DIR)/.debmake/fakeroot"
export FAKEROOT

# Only do the master packaging rules if we're the toplevel make invocation.
ifeq ($(MAKELEVEL),0)
FW_PACKAGE_NAME := $(shell grep Package $(TOP_DIR)/layout/DEBIAN/control | cut -d' ' -f2)
FW_PACKAGE_ARCH := $(shell grep Architecture $(TOP_DIR)/layout/DEBIAN/control | cut -d' ' -f2)
FW_PACKAGE_VERSION := $(shell grep Version $(TOP_DIR)/layout/DEBIAN/control | cut -d' ' -f2)

FW_PACKAGE_BUILDNUM = $(shell TOP_DIR="$(TOP_DIR)" $(FW_SCRIPTDIR)/deb_build_num.sh $(FW_PACKAGE_NAME) $(FW_PACKAGE_VERSION))
FW_PACKAGE_DEBVERSION = $(shell grep Version $(FW_PACKAGE_STAGING_DIR)/DEBIAN/control | cut -d' ' -f2)

ifdef STOREPACKAGE
	FW_PACKAGE_FILENAME = cydiastore_$(FW_PACKAGE_NAME)_v$(FW_PACKAGE_DEBVERSION)
else
	FW_PACKAGE_FILENAME = $(FW_PACKAGE_NAME)_$(FW_PACKAGE_DEBVERSION)_$(FW_PACKAGE_ARCH)
endif

before-package::
	-rm -rf $(FW_PACKAGE_STAGING_DIR)
	svn export $(FW_PROJECT_DIR)/layout $(FW_PACKAGE_STAGING_DIR) || cp -r $(FW_PROJECT_DIR)/layout $(FW_PACKAGE_STAGING_DIR)
	$(FAKEROOT) -c

internal-package::

after-package-buildno::
	sed -e 's/Version: \(.*\)/Version: \1-$(FW_PACKAGE_BUILDNUM)/g' $(FW_PROJECT_DIR)/layout/DEBIAN/control > $(FW_PACKAGE_STAGING_DIR)/DEBIAN/control
	echo "Installed-Size: $(shell du $(DU_EXCLUDE) DEBIAN -ks $(FW_PACKAGE_STAGING_DIR) | cut -f 1)" >> $(FW_PACKAGE_STAGING_DIR)/DEBIAN/control

after-package:: after-package-buildno
	$(FAKEROOT) -r dpkg-deb -b $(FW_PACKAGE_STAGING_DIR) $(FW_PROJECT_DIR)/$(FW_PACKAGE_FILENAME).deb

ifeq ($(FW_DEVICE_IP),)
install::
	@echo "Error: $(MAKE) install requires that you set FW_DEVICE_IP in your environment.\nIt is also recommended that you have public-key authentication set up for root over SSH, or you'll be entering your password a lot."; exit 1
else
install:: internal-install after-install
internal-install::
	scp $(FW_PROJECT_DIR)/$(FW_PACKAGE_FILENAME).deb root@$(FW_DEVICE_IP):
	ssh root@$(FW_DEVICE_IP) "dpkg -i $(FW_PACKAGE_FILENAME).deb"

after-install::
endif

else

before-package::

internal-package::

after-package::

endif # MAKELEVEL

endif # FW_PACKAGING_RULES_LOADED