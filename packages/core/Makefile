include $(TOPDIR)/rules.mk

PKG_NAME:=picoclaw
PKG_VERSION:=main
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/sipeed/picoclaw.git
PKG_SOURCE_VERSION:=main

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/golang-package.mk

define Package/picoclaw
  SECTION:=net
  CATEGORY:=Network
  TITLE:=PicoClaw AI Core
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

$(eval $(call GoBinPackage,picoclaw))
$(eval $(call BuildPackage,picoclaw))
